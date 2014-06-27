/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
  
 */

#import "AAPLCollectionViewGridLayout_Internal.h"
#import "AAPLLayoutMetrics_Private.h"
#import "AAPLDataSource.h"
#import "AAPLCollectionViewGridLayoutAttributes_Private.h"
#import "UICollectionView+Helpers.h"

static inline NSString *AAPLStringFromBOOL(BOOL value)
{
    return value ? @"YES" : @"NO";
}

static inline NSString *AAPLStringFromNSIndexPath(NSIndexPath *indexPath)
{
    NSMutableArray *indexes = [NSMutableArray array];
    NSUInteger numberOfIndexes = indexPath.length;

    for (NSUInteger currentIndex = 0; currentIndex < numberOfIndexes; ++ currentIndex)
        [indexes addObject:@([indexPath indexAtPosition:currentIndex])];

    return [NSString stringWithFormat:@"(%@)", [indexes componentsJoinedByString:@", "]];
}

#define LAYOUT_DEBUGGING 0
#define LAYOUT_LOGGING 0

#if LAYOUT_DEBUGGING
#define LAYOUT_LOGGING 1
#endif

#if LAYOUT_LOGGING
#define LAYOUT_TRACE() NSLog(@"%@", NSStringFromSelector(_cmd))
#define LAYOUT_LOG(FORMAT, ...) NSLog(@"%@ " FORMAT, NSStringFromSelector(_cmd), __VA_ARGS__)
#else
#define LAYOUT_TRACE()
#define LAYOUT_LOG(...)
#endif


#define DRAG_SHADOW_HEIGHT 19

#define SCROLL_SPEED_MAX_MULTIPLIER 4.0
#define FRAMES_PER_SECOND 60.0
//#define MEASURE_HEIGHT UILayoutFittingExpandedSize.height
#define MEASURE_HEIGHT 100

#define DEFAULT_ROW_HEIGHT 44

#define DEFAULT_ZINDEX 1
#define SEPARATOR_ZINDEX 100
#define HEADER_ZINDEX 1000
#define PINNED_HEADER_ZINDEX 10000

static NSString * const AAPLGridLayoutRowSeparatorKind = @"AAPLGridLayoutRowSeparatorKind";
static NSString * const AAPLGridLayoutColumnSeparatorKind = @"AAPLGridLayoutColumnSeparatorKind";
static NSString * const AAPLGridLayoutSectionSeparatorKind = @"AAPLGridLayoutSectionSeparatorKind";
static NSString * const AAPLGridLayoutGlobalHeaderBackgroundKind = @"AAPLGridLayoutGlobalHeaderBackgroundKind";

static inline CGPoint AAPLPointAddPoint(CGPoint point1, CGPoint point2)
{
    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
}

typedef NS_ENUM(NSInteger, AAPLAutoScrollDirection) {
    AAPLAutoScrollDirectionUnknown = 0,
    AAPLAutoScrollDirectionUp,
    AAPLAutoScrollDirectionDown,
    AAPLAutoScrollDirectionLeft,
    AAPLAutoScrollDirectionRight
};


/// Used to look up supplementary & decoration attributes
@interface AAPLIndexPathKind : NSObject<NSCopying>
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, copy) NSString *kind;
@end

@implementation AAPLIndexPathKind
- (instancetype)initWithIndexPath:(NSIndexPath *)indexPath kind:(NSString *)kind
{
    self = [super init];
    if (!self)
        return nil;
    _indexPath = indexPath;
    _kind = [kind copy];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] initWithIndexPath:_indexPath kind:_kind];
}

- (NSUInteger)hash
{
    NSUInteger prime = 31;
    NSUInteger result = 1;

    result = prime * result + [_indexPath hash];
    result = prime * result + [_kind hash];
    return result;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[AAPLIndexPathKind class]])
        return NO;

    AAPLIndexPathKind *other = object;

    if (_indexPath == other->_indexPath && _kind == other->_kind)
        return YES;

    if (!_indexPath || ![_indexPath isEqual:other->_indexPath])
        return NO;
    if (!_kind || ![_kind isEqualToString:other->_kind])
        return NO;

    return YES;
}

@end


@interface AAPLGridLayoutSeparatorView : UICollectionReusableView
@end

@implementation AAPLGridLayoutSeparatorView
- (void)applyLayoutAttributes:(AAPLCollectionViewGridLayoutAttributes *)layoutAttributes
{
    NSAssert([layoutAttributes isKindOfClass:[AAPLCollectionViewGridLayoutAttributes class]], @"layout attributes not an instance of AAPLCollectionViewGridLayoutAttributes");
    self.backgroundColor = layoutAttributes.backgroundColor;
}
@end

@interface AAPLCollectionViewGridLayout ()
@property (nonatomic) CGSize layoutSize;
@property (nonatomic) CGSize oldLayoutSize;
@property (nonatomic) BOOL preparingLayout;

/// Scroll direction isn't really supported, but it might be in the future. Always returns UICollectionViewScrollDirectionVertical.
@property (nonatomic, readonly) UICollectionViewScrollDirection scrollDirection;
@property (nonatomic) CGFloat scrollingSpeed;
@property (nonatomic) UIEdgeInsets scrollingTriggerEdgeInsets;
@property (strong, nonatomic) NSIndexPath *selectedItemIndexPath;
@property (strong, nonatomic) NSIndexPath *sourceItemIndexPath;
@property (strong, nonatomic) UIView *currentView;
@property (assign, nonatomic) CGPoint currentViewCenter;
@property (assign, nonatomic) CGPoint panTranslationInCollectionView;
@property (strong, nonatomic) CADisplayLink *displayLink;
@property (nonatomic) AAPLAutoScrollDirection autoscrollDirection;
@property (nonatomic) CGRect autoscrollBounds;
@property (nonatomic) CGRect dragBounds;
@property (nonatomic) CGSize dragCellSize;

@property (nonatomic) NSInteger totalNumberOfItems;
@property (nonatomic, strong) NSMutableArray *layoutAttributes;
@property (nonatomic, strong) NSMutableArray *pinnableAttributes;
@property (nonatomic, strong) AAPLGridLayoutInfo *layoutInfo;
@property (nonatomic, strong) NSMutableDictionary *indexPathKindToSupplementaryAttributes;
@property (nonatomic, strong) NSMutableDictionary *oldIndexPathKindToSupplementaryAttributes;
@property (nonatomic, strong) NSMutableDictionary *indexPathKindToDecorationAttributes;
@property (nonatomic, strong) NSMutableDictionary *oldIndexPathKindToDecorationAttributes;
@property (nonatomic, strong) NSMutableDictionary *indexPathToItemAttributes;
@property (nonatomic, strong) NSMutableDictionary *oldIndexPathToItemAttributes;

/// A dictionary mapping the section index to the AAPLDataSourceSectionOperationDirection value
@property (nonatomic, strong) NSMutableDictionary *updateSectionDirections;
@property (nonatomic, strong) NSMutableSet *insertedIndexPaths;
@property (nonatomic, strong) NSMutableSet *removedIndexPaths;
@property (nonatomic, strong) NSMutableIndexSet *insertedSections;
@property (nonatomic, strong) NSMutableIndexSet *removedSections;
@property (nonatomic, strong) NSMutableIndexSet *reloadedSections;
@property (nonatomic) CGPoint contentOffsetDelta;
@end

@implementation AAPLCollectionViewGridLayout  {
    struct {
        /// the data source has the snapshot metrics method
        unsigned int dataSourceHasSnapshotMetrics:1;
        /// layout data becomes invalid if the data source changes
        unsigned int layoutDataIsValid:1;
        /// layout metrics will only be valid if layout data is also valid
        unsigned int layoutMetricsAreValid:1;
        /// contentOffset of collection view is valid
        unsigned int useCollectionViewContentOffset:1;
    } _flags;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    [self aapl_commonInitCollectionViewGridLayout];
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    [self aapl_commonInitCollectionViewGridLayout];
    return self;
}

- (void)aapl_commonInitCollectionViewGridLayout
{
    [self registerClass:[AAPLGridLayoutSeparatorView class] forDecorationViewOfKind:AAPLGridLayoutRowSeparatorKind];
    [self registerClass:[AAPLGridLayoutSeparatorView class] forDecorationViewOfKind:AAPLGridLayoutColumnSeparatorKind];
    [self registerClass:[AAPLGridLayoutSeparatorView class] forDecorationViewOfKind:AAPLGridLayoutSectionSeparatorKind];
    [self registerClass:[AAPLGridLayoutSeparatorView class] forDecorationViewOfKind:AAPLGridLayoutGlobalHeaderBackgroundKind];

    _indexPathKindToDecorationAttributes = [NSMutableDictionary dictionary];
    _oldIndexPathKindToDecorationAttributes = [NSMutableDictionary dictionary];
    _indexPathToItemAttributes = [NSMutableDictionary dictionary];
    _oldIndexPathToItemAttributes = [NSMutableDictionary dictionary];
    _indexPathKindToSupplementaryAttributes = [NSMutableDictionary dictionary];
    _oldIndexPathKindToSupplementaryAttributes = [NSMutableDictionary dictionary];

    _scrollingTriggerEdgeInsets = UIEdgeInsetsMake(100, 100, 100, 100);

    _updateSectionDirections = [NSMutableDictionary dictionary];
    _layoutAttributes = [NSMutableArray array];
    _pinnableAttributes = [NSMutableArray array];
}


#pragma mark - Properties

- (void)setEditing:(BOOL)editing
{
    if (editing == _editing)
        return;

    _editing = editing;
    [self invalidateLayout];
}

#pragma mark - Drag & Drop

- (void)beginDraggingItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionView *collectionView = self.collectionView;
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];

    CGRect dragFrame = cell.frame;
    _dragCellSize = dragFrame.size;

    UIView *snapshotView = [cell snapshotViewAfterScreenUpdates:YES];

    UIImageView *shadowView = [[UIImageView alloc] initWithFrame:CGRectInset(dragFrame, 0, -DRAG_SHADOW_HEIGHT)];
    shadowView.image = [[UIImage imageNamed:@"AAPLDragShadow"] resizableImageWithCapInsets:UIEdgeInsetsMake(DRAG_SHADOW_HEIGHT, 1, DRAG_SHADOW_HEIGHT, 1)];
    shadowView.opaque = NO;
    
    dragFrame.origin = CGPointMake(0, DRAG_SHADOW_HEIGHT);
    snapshotView.frame = dragFrame;
    [shadowView addSubview:snapshotView];
    _currentView = shadowView;

    _currentView.center = cell.center;
    [collectionView addSubview:_currentView];

    _currentViewCenter = _currentView.center;
    _selectedItemIndexPath = indexPath;
    _sourceItemIndexPath = indexPath;

    AAPLGridLayoutSectionInfo *sectionInfo = [self sectionInfoForSectionAtIndex:indexPath.section];
    AAPLGridLayoutItemInfo *itemInfo = sectionInfo.items[indexPath.item];
    itemInfo.dragging = YES;

    _autoscrollBounds = CGRectZero;
    _autoscrollBounds.size = collectionView.frame.size;
    _autoscrollBounds = UIEdgeInsetsInsetRect(_autoscrollBounds, _scrollingTriggerEdgeInsets);

    CGRect collectionViewFrame = collectionView.frame;
    CGFloat collectionViewWidth = CGRectGetWidth(collectionViewFrame);
    CGFloat collectionViewHeight = CGRectGetHeight(collectionViewFrame);

    _dragBounds = CGRectMake(_dragCellSize.width/2, _dragCellSize.height/2, collectionViewWidth - _dragCellSize.width, collectionViewHeight - _dragCellSize.height);
}

- (void)cancelDragging
{
    [_currentView removeFromSuperview];

    AAPLGridLayoutSectionInfo *sourceSection = [self sectionInfoForSectionAtIndex:_sourceItemIndexPath.section];
    AAPLGridLayoutSectionInfo *destinationSection = [self sectionInfoForSectionAtIndex:_selectedItemIndexPath.section];

    destinationSection.phantomCellIndex = NSNotFound;
    destinationSection.phantomCellSize = CGSizeZero;

    NSInteger fromIndex = _sourceItemIndexPath.item;

    AAPLGridLayoutItemInfo *item = sourceSection.items[fromIndex];
    item.dragging = NO;

    AAPLGridLayoutInvalidationContext *context = [[AAPLGridLayoutInvalidationContext alloc] init];
    context.invalidateLayoutMetrics = YES;
    [self invalidateLayoutWithContext:context];
}

- (void)endDragging
{
    [_currentView removeFromSuperview];

    AAPLGridLayoutSectionInfo *sourceSection = [self sectionInfoForSectionAtIndex:_sourceItemIndexPath.section];
    AAPLGridLayoutSectionInfo *destinationSection = [self sectionInfoForSectionAtIndex:_selectedItemIndexPath.section];

    destinationSection.phantomCellIndex = NSNotFound;
    destinationSection.phantomCellSize = CGSizeZero;

    NSIndexPath *fromIndexPath = _sourceItemIndexPath;
    NSIndexPath *toIndexPath = _selectedItemIndexPath;

    NSInteger fromIndex = fromIndexPath.item;
    NSInteger toIndex = toIndexPath.item;

    AAPLGridLayoutItemInfo *item = sourceSection.items[fromIndex];
    item.dragging = NO;

    BOOL needsUpdate = YES;

    if (sourceSection == destinationSection) {
        if (fromIndex == toIndex)
            needsUpdate = NO;

        if (fromIndex < toIndex) {
            toIndex--;
            toIndexPath = [NSIndexPath indexPathForItem:toIndex inSection:toIndexPath.section];
        }
    }

    if (needsUpdate) {
        [sourceSection.items removeObjectAtIndex:fromIndex];
        [destinationSection.items insertObject:item atIndex:toIndex];

        // Tell the data source, but don't animate because we've already updated everything in place.
        [UIView performWithoutAnimation:^{
            UICollectionView *collectionView = self.collectionView;
            AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
            if ([dataSource isKindOfClass:[AAPLDataSource class]])
                [dataSource collectionView:collectionView moveItemAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
        }];
    }

    AAPLGridLayoutInvalidationContext *context = [[AAPLGridLayoutInvalidationContext alloc] init];
    context.invalidateLayoutMetrics = YES;
    [self invalidateLayoutWithContext:context];

    _selectedItemIndexPath = nil;
}

- (UICollectionViewScrollDirection)scrollDirection
{
    return UICollectionViewScrollDirectionVertical;
}

- (void)invalidateScrollTimer
{
    if (!_displayLink.paused)
        [_displayLink invalidate];
    _displayLink = nil;
}

- (void)setupScrollTimerInDirection:(AAPLAutoScrollDirection)direction {
    if (_displayLink && !_displayLink.paused) {
        if (_autoscrollDirection == direction)
            return;
    }

    [self invalidateScrollTimer];

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleScroll:)];
    _autoscrollDirection = direction;

    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

// Tight loop, allocate memory sparely, even if they are stack allocation.
- (void)handleScroll:(CADisplayLink *)displayLink
{
    AAPLAutoScrollDirection direction = _autoscrollDirection;
    if (direction == AAPLAutoScrollDirectionUnknown)
        return;

    UICollectionView *collectionView = self.collectionView;
    CGSize frameSize = collectionView.bounds.size;
    CGSize contentSize = collectionView.contentSize;
    CGPoint contentOffset = collectionView.contentOffset;

    // Need to keep the distance as an integer, because the contentOffset property is automatically rounded. This would cause the view center to begin to diverge from the scrolling and appear to slip away from under the user's finger.
    CGFloat distance = rint(self.scrollingSpeed / FRAMES_PER_SECOND);
    CGPoint translation = CGPointZero;

    switch (direction) {
        case AAPLAutoScrollDirectionUp: {
            distance = -distance;
            CGFloat minY = 0.0f;

            if ((contentOffset.y + distance) <= minY) {
                distance = -contentOffset.y;
            }

            translation = CGPointMake(0.0f, distance);
            break;
        }

        case AAPLAutoScrollDirectionDown: {
            CGFloat maxY = MAX(contentSize.height, frameSize.height) - frameSize.height;

            if ((contentOffset.y + distance) >= maxY) {
                distance = maxY - contentOffset.y;
            }

            translation = CGPointMake(0.0f, distance);
            break;
        }

        case AAPLAutoScrollDirectionLeft: {
            distance = -distance;
            CGFloat minX = 0.0f;

            if ((contentOffset.x + distance) <= minX) {
                distance = -contentOffset.x;
            }

            translation = CGPointMake(distance, 0.0f);
            break;
        }

        case AAPLAutoScrollDirectionRight: {
            CGFloat maxX = MAX(contentSize.width, frameSize.width) - frameSize.width;

            if ((contentOffset.x + distance) >= maxX) {
                distance = maxX - contentOffset.x;
            }

            translation = CGPointMake(distance, 0.0f);
            break;
        }

        default:
            break;
    }

    _currentViewCenter = AAPLPointAddPoint(_currentViewCenter, translation);
    _currentView.center = [self pointConstrainedToDragBounds:AAPLPointAddPoint(_currentViewCenter, _panTranslationInCollectionView)];
    collectionView.contentOffset = AAPLPointAddPoint(contentOffset, translation);
}

- (void)makeSpaceForDraggedCell
{
    NSIndexPath *newIndexPath = [self.collectionView indexPathForItemAtPoint:self.currentView.center];
    NSIndexPath *previousIndexPath = self.selectedItemIndexPath;

    AAPLGridLayoutSectionInfo *oldSection = [self sectionInfoForSectionAtIndex:previousIndexPath.section];
    AAPLGridLayoutSectionInfo *newSection = [self sectionInfoForSectionAtIndex:newIndexPath.section];

    if (!newIndexPath)
        return;

    // If I've already made space for the cell, all indexes in that section need to be incremented by 1
    if (oldSection.phantomCellIndex == previousIndexPath.item && newIndexPath.section == previousIndexPath.section && newIndexPath.item >= oldSection.phantomCellIndex)
        newIndexPath = [NSIndexPath indexPathForItem:newIndexPath.item+1 inSection:newIndexPath.section];

    if ([newIndexPath isEqual:previousIndexPath])
        return;

    UICollectionView *collectionView = self.collectionView;
    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        return;

    if (![dataSource collectionView:collectionView canMoveItemAtIndexPath:_sourceItemIndexPath toIndexPath:newIndexPath]) {
        NSLog(@"Can't MOVE");
        return;
    }

    oldSection.phantomCellIndex = NSNotFound;
    oldSection.phantomCellSize = CGSizeZero;
    newSection.phantomCellIndex = newIndexPath.item;
    newSection.phantomCellSize = _dragCellSize;
    _selectedItemIndexPath = newIndexPath;

    AAPLGridLayoutInvalidationContext *context = [[AAPLGridLayoutInvalidationContext alloc] init];
    context.invalidateLayoutMetrics = YES;
    [self invalidateLayoutWithContext:context];
}

- (CGPoint)pointConstrainedToDragBounds:(CGPoint)viewCenter
{
    if (UICollectionViewScrollDirectionVertical == self.scrollDirection) {
        CGFloat left = CGRectGetMinX(_dragBounds);
        CGFloat right = CGRectGetMaxX(_dragBounds);
        if (viewCenter.x < left)
            viewCenter.x = left;
        else if (viewCenter.x > right)
            viewCenter.x = right;
    }

    return viewCenter;
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer
{
    UICollectionView *collectionView = self.collectionView;
    CGPoint contentOffset = collectionView.contentOffset;

    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:

        case UIGestureRecognizerStateChanged: {
            self.panTranslationInCollectionView = [gestureRecognizer translationInView:collectionView];
            CGPoint viewCenter = AAPLPointAddPoint(self.currentViewCenter, self.panTranslationInCollectionView);

            self.currentView.center = [self pointConstrainedToDragBounds:viewCenter];

            [self makeSpaceForDraggedCell];

            CGPoint location = [gestureRecognizer locationInView:collectionView];

            switch (self.scrollDirection) {
                case UICollectionViewScrollDirectionVertical: {
                    CGFloat y = location.y - contentOffset.y;
                    CGFloat top = CGRectGetMinY(_autoscrollBounds);
                    CGFloat bottom = CGRectGetMaxY(_autoscrollBounds);

                    if (y < top) {
                        self.scrollingSpeed = 300 * ((top - y) / _scrollingTriggerEdgeInsets.top) * SCROLL_SPEED_MAX_MULTIPLIER;
                        [self setupScrollTimerInDirection:AAPLAutoScrollDirectionUp];
                    }
                    else if (y > bottom) {
                        self.scrollingSpeed = 300 * ((y - bottom) / _scrollingTriggerEdgeInsets.bottom) * SCROLL_SPEED_MAX_MULTIPLIER;
                        [self setupScrollTimerInDirection:AAPLAutoScrollDirectionDown];
                    }
                    else
                        [self invalidateScrollTimer];
                    break;
                }

                case UICollectionViewScrollDirectionHorizontal: {
                    CGFloat x = location.x - contentOffset.x;
                    CGFloat left = CGRectGetMinX(_autoscrollBounds);
                    CGFloat right = CGRectGetMaxX(_autoscrollBounds);

                    if (viewCenter.x < left) {
                        self.scrollingSpeed = 300 * ((left - x) / _scrollingTriggerEdgeInsets.left) * SCROLL_SPEED_MAX_MULTIPLIER;
                        [self setupScrollTimerInDirection:AAPLAutoScrollDirectionLeft];
                    }
                    else if (viewCenter.x > right) {
                        self.scrollingSpeed = 300 * ((x - right) / _scrollingTriggerEdgeInsets.right) * SCROLL_SPEED_MAX_MULTIPLIER;
                        [self setupScrollTimerInDirection:AAPLAutoScrollDirectionRight];
                    }
                    else
                        [self invalidateScrollTimer];
                    break;
                }
            }
            break;
        }

        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            [self invalidateScrollTimer];
            break;
        }
            
        default:
            break;
    }
}


#pragma mark - UICollectionViewLayout API

+ (Class)layoutAttributesClass
{
    return [AAPLCollectionViewGridLayoutAttributes class];
}

+ (Class)invalidationContextClass
{
    return [AAPLGridLayoutInvalidationContext class];
}

- (void)invalidateLayoutWithContext:(AAPLGridLayoutInvalidationContext *)context
{
    NSParameterAssert([context isKindOfClass:[AAPLGridLayoutInvalidationContext class]]);

    BOOL invalidateDataSourceCounts = context.invalidateDataSourceCounts;
    BOOL invalidateEverything = context.invalidateEverything;
    BOOL invalidateLayoutMetrics = context.invalidateLayoutMetrics;

    _flags.useCollectionViewContentOffset = context.invalidateLayoutOrigin;

    if (invalidateEverything) {
        _flags.layoutMetricsAreValid = NO;
        _flags.layoutDataIsValid = NO;
    }

    if (_flags.layoutDataIsValid) {
        _flags.layoutMetricsAreValid = !(invalidateDataSourceCounts || invalidateLayoutMetrics);

        if (invalidateDataSourceCounts)
            _flags.layoutDataIsValid = NO;
    }
    LAYOUT_LOG(@"LayoutDataIsValid = %@ LayoutMetricsAreValid = %@", (_flags.layoutDataIsValid ? @"YES" : @"NO"), (_flags.layoutMetricsAreValid ? @"YES" : @"NO"));

    [super invalidateLayoutWithContext:context];
}

- (void)prepareLayout
{
    LAYOUT_TRACE();
    LAYOUT_LOG(@"bounds=%@", NSStringFromCGRect(self.collectionView.bounds));
    if (!self.collectionView.window)
        _flags.layoutMetricsAreValid = _flags.layoutDataIsValid = NO;

    if (!CGRectIsEmpty(self.collectionView.bounds)) {
        [self buildLayout];
    }
    
    [super prepareLayout];
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect;
{
    LAYOUT_TRACE();

    NSMutableArray *result = [NSMutableArray array];

    [self filterSpecialAttributes];

    for (AAPLCollectionViewGridLayoutAttributes *attributes in _layoutAttributes) {
        if (CGRectIntersectsRect(attributes.frame, rect))
            [result addObject:attributes];
    }

#if LAYOUT_DEBUGGING
    LAYOUT_LOG(@"rect=%@", NSStringFromCGRect(rect));
    for (AAPLCollectionViewGridLayoutAttributes *attr in result) {
        NSString *type;
        switch (attr.representedElementCategory) {
            case UICollectionElementCategoryCell:
                type = @"CELL";
                break;
            case UICollectionElementCategoryDecorationView:
                type = @"DECORATION";
                break;
            case UICollectionElementCategorySupplementaryView:
                type = @"SUPPLEMENTARY";
                break;
        }
        LAYOUT_LOG(@"  %@ %@ indexPath=%@ frame=%@ hidden=%@", type, (attr.representedElementKind ?:@""), AAPLStringFromNSIndexPath(attr.indexPath), NSStringFromCGRect(attr.frame), AAPLStringFromBOOL(attr.hidden));
    }
#endif

    return result;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_TRACE();

    NSInteger sectionIndex = indexPath.section;
    NSInteger itemIndex = indexPath.item;

    if (sectionIndex < 0 || sectionIndex >= [_layoutInfo.sections count])
        return nil;

    AAPLCollectionViewGridLayoutAttributes *attributes = _indexPathToItemAttributes[indexPath];
    if (attributes) {
        LAYOUT_LOG(@"Found attributes for row %ld,%ld: %@", (long)sectionIndex, (long)itemIndex, NSStringFromCGRect(attributes.frame));
        return attributes;
    }

    AAPLGridLayoutSectionInfo *section = [self sectionInfoForSectionAtIndex:sectionIndex];

    if (itemIndex < 0 || itemIndex >= [section.items count])
        return nil;

    UICollectionView *collectionView = self.collectionView;
    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        dataSource = nil;

    AAPLGridLayoutItemInfo *item = section.items[itemIndex];

    attributes = [[self.class layoutAttributesClass] layoutAttributesForCellWithIndexPath:indexPath];

    // Drag & Drop
    attributes.hidden = item.dragging;

    // Need to be clever if we're still preparing the layout…
    if (_preparingLayout) {
        attributes.hidden = YES;
    }
    attributes.frame = item.frame;
    attributes.zIndex = DEFAULT_ZINDEX;
    attributes.backgroundColor = section.backgroundColor;
    attributes.selectedBackgroundColor = section.selectedBackgroundColor;
    attributes.editing = _editing ? [dataSource collectionView:collectionView canEditItemAtIndexPath:indexPath] : NO;
    attributes.movable = _editing ? [dataSource collectionView:collectionView canMoveItemAtIndexPath:indexPath] : NO;
    attributes.columnIndex = item.columnIndex;

    LAYOUT_LOG(@"Created attributes for %@: %@ hidden = %@ preparingLayout", AAPLStringFromNSIndexPath(indexPath), NSStringFromCGRect(attributes.frame), AAPLStringFromBOOL(attributes.hidden), AAPLStringFromBOOL(_preparingLayout));

    if (!_preparingLayout)
        _indexPathToItemAttributes[indexPath] = attributes;
    return attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_TRACE();

    NSInteger sectionIndex = (indexPath.length == 1 ? AAPLGlobalSection : indexPath.section);
    NSInteger itemIndex = (indexPath.length == 1 ? [indexPath indexAtPosition:0] : indexPath.item);

    AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
    AAPLCollectionViewGridLayoutAttributes *attributes = _indexPathKindToSupplementaryAttributes[indexPathKind];
    if (attributes)
        return attributes;

    AAPLGridLayoutSectionInfo *section = [self sectionInfoForSectionAtIndex:sectionIndex];
    CGRect frame = CGRectZero;
    AAPLGridLayoutSupplementalItemInfo *supplementalItem;

    NSArray *supplementalItems;

    if ([kind isEqualToString:AAPLCollectionElementKindPlaceholder])
        // supplementalItem might become nil if there's no placedholder, but that just means we return attributes that are empty
        supplementalItem = section.placeholder;
    else {
        if ([kind isEqualToString:UICollectionElementKindSectionHeader])
            supplementalItems = section.headers;
        else if ([kind isEqualToString:UICollectionElementKindSectionFooter])
            supplementalItems = section.footers;

        if (itemIndex < 0 || itemIndex >= [supplementalItems count])
            return nil;

        supplementalItem = supplementalItems[itemIndex];
    }

    attributes = [[self.class layoutAttributesClass] layoutAttributesForSupplementaryViewOfKind:kind withIndexPath:indexPath];

    // Need to be clever if we're still preparing the layout…
    if (_preparingLayout) {
        attributes.hidden = YES;
    }

    frame = supplementalItem.frame;

    attributes.frame = frame;
    attributes.zIndex = HEADER_ZINDEX;

    attributes.editing = _editing;
    attributes.padding = supplementalItem.padding;
    attributes.backgroundColor = supplementalItem.backgroundColor ? : section.backgroundColor;
    attributes.selectedBackgroundColor = section.selectedBackgroundColor;

    if (!_preparingLayout)
        _indexPathKindToSupplementaryAttributes[indexPathKind] = attributes;
    return attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString*)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_TRACE();

//    NSInteger sectionIndex = (indexPath.length == 1 ? AAPLGlobalSection : indexPath.section);
//    NSInteger itemIndex = (indexPath.length == 1 ? [indexPath indexAtPosition:0] : indexPath.item);

    AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
    UICollectionViewLayoutAttributes *attributes = _indexPathKindToDecorationAttributes[indexPathKind];
    if (attributes)
        return attributes;

    // FIXME: don't know… but returning nil crashes.
    return nil;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds
{
    CGRect bounds = self.collectionView.bounds;
    AAPLGridLayoutInvalidationContext *context = (AAPLGridLayoutInvalidationContext *)[super invalidationContextForBoundsChange:newBounds];

    context.invalidateLayoutOrigin = newBounds.origin.x != bounds.origin.x || newBounds.origin.y != bounds.origin.y;

    // Only recompute the layout if the actual width has changed.
    context.invalidateLayoutMetrics = ((newBounds.size.width != bounds.size.width) || (newBounds.origin.x != bounds.origin.x));
    return context;
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity
{
    return proposedContentOffset;
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
{
    UICollectionView *collectionView = self.collectionView;
    UIEdgeInsets insets = collectionView.contentInset;
    CGPoint targetContentOffset = proposedContentOffset;
    targetContentOffset.y += insets.top;

    CGFloat availableHeight = CGRectGetHeight(UIEdgeInsetsInsetRect(collectionView.bounds, insets));
    targetContentOffset.y = MIN(targetContentOffset.y, MAX(0, _layoutSize.height - availableHeight));

    NSInteger firstInsertedIndex = [self.insertedSections firstIndex];
    if (NSNotFound != firstInsertedIndex && AAPLDataSourceSectionOperationDirectionNone != [self.updateSectionDirections[@(firstInsertedIndex)] integerValue]) {
        AAPLGridLayoutSectionInfo *globalSection = [self sectionInfoForSectionAtIndex:AAPLGlobalSection];
        CGFloat globalNonPinnableHeight = [self heightOfAttributes:globalSection.nonPinnableHeaderAttributes];
        CGFloat globalPinnableHeight = CGRectGetHeight(globalSection.frame) - globalNonPinnableHeight;

        AAPLGridLayoutSectionInfo *sectionInfo = [self sectionInfoForSectionAtIndex:firstInsertedIndex];
        CGFloat minY = CGRectGetMinY(sectionInfo.frame);
        if (targetContentOffset.y + globalPinnableHeight > minY) {
            // need to make the section visable
            targetContentOffset.y = MAX(globalNonPinnableHeight, minY - globalPinnableHeight);
        }
    }

    targetContentOffset.y -= insets.top;

    LAYOUT_LOG(@"proposedContentOffset: %@; layoutSize: %@; availableHeight: %g; targetContentOffset: %@", NSStringFromCGPoint(proposedContentOffset), NSStringFromCGSize(_layoutSize), availableHeight, NSStringFromCGPoint(targetContentOffset));
    return targetContentOffset;
}

- (CGSize)collectionViewContentSize
{
    LAYOUT_TRACE();
    return _layoutSize;
}

- (void)prepareForCollectionViewUpdates:(NSArray *)updateItems
{
    LAYOUT_TRACE();
    self.insertedIndexPaths = [NSMutableSet set];
    self.removedIndexPaths = [NSMutableSet set];
    self.insertedSections = [NSMutableIndexSet indexSet];
    self.removedSections = [NSMutableIndexSet indexSet];
    self.reloadedSections = [NSMutableIndexSet indexSet];

    for (UICollectionViewUpdateItem *updateItem in updateItems) {
        if (UICollectionUpdateActionInsert == updateItem.updateAction) {
            NSIndexPath *indexPath = updateItem.indexPathAfterUpdate;
            if (NSNotFound == indexPath.item)
                [self.insertedSections addIndex:indexPath.section];
            else
                [self.insertedIndexPaths addObject:indexPath];
        }
        else if (UICollectionUpdateActionDelete == updateItem.updateAction) {
            NSIndexPath *indexPath = updateItem.indexPathBeforeUpdate;
            if (NSNotFound == indexPath.item)
                [self.removedSections addIndex:indexPath.section];
            else
                [self.removedIndexPaths addObject:indexPath];
        }
        else if (UICollectionUpdateActionReload == updateItem.updateAction) {
            NSIndexPath *indexPath = updateItem.indexPathAfterUpdate;
            if (NSNotFound == indexPath.item)
                [self.reloadedSections addIndex:indexPath.section];
        }
    }

    UICollectionView *collectionView = self.collectionView;
    CGPoint contentOffset = collectionView.contentOffset;

    CGPoint newContentOffset = [self targetContentOffsetForProposedContentOffset:contentOffset];
    self.contentOffsetDelta = CGPointMake(newContentOffset.x - contentOffset.x, newContentOffset.y - contentOffset.y);

    [super prepareForCollectionViewUpdates:updateItems];
}

- (void)finalizeCollectionViewUpdates
{
    LAYOUT_TRACE();
    [super finalizeCollectionViewUpdates];
    self.insertedIndexPaths = nil;
    self.removedIndexPaths = nil;
    self.insertedSections = nil;
    self.removedSections = nil;
    self.reloadedSections = nil;
    [self.updateSectionDirections removeAllObjects];
}

// These methods are called by collection view during an update block.
// Return an array of index paths to indicate views that the layout is deleting or inserting in response to the update.
//- (NSArray *)indexPathsToDeleteForSupplementaryViewOfKind:(NSString *)kind
//{
//}

// FIXME: <rdar://problem/16520988>
// This method is ACTUALLY called for supplementary views
- (NSArray *)indexPathsToDeleteForDecorationViewOfKind:(NSString *)kind
{
    NSMutableArray *result = [NSMutableArray array];

    // FIXME: <rdar://problem/16117605> Be smarter about updating the attributes on layout updates
    [_oldIndexPathKindToDecorationAttributes enumerateKeysAndObjectsUsingBlock:^(AAPLIndexPathKind *indexPathKind, AAPLCollectionViewGridLayoutAttributes *attributes, BOOL *stop) {
        if (![indexPathKind.kind isEqualToString:kind])
            return;
        // If we have a similar decoration view in the new attributes, skip it.
        if (_indexPathKindToDecorationAttributes[indexPathKind])
            return;
        [result addObject:indexPathKind.indexPath];
    }];

    return result;
}


- (NSArray *)indexPathsToInsertForSupplementaryViewOfKind:(NSString *)kind
{
    LAYOUT_LOG(@"kind=%@", kind);
    return [super indexPathsToInsertForSupplementaryViewOfKind:kind];
}

//- (NSArray *)indexPathsToInsertForDecorationViewOfKind:(NSString *)kind
//{
//}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingDecorationElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"kind:%@ indexPath:%@", kind, indexPath);

    AAPLCollectionViewGridLayoutAttributes *result = nil;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSection);

    AAPLDataSourceSectionOperationDirection direction = [_updateSectionDirections[@(section)] intValue];
    if (AAPLDataSourceSectionOperationDirectionNone != direction) {
        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
        return [self initialLayoutAttributesForAttributes:[_indexPathKindToDecorationAttributes[indexPathKind] copy] slidingInFromDirection:direction];
    }

    BOOL inserted = [self.insertedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
    result = [_indexPathKindToDecorationAttributes[indexPathKind] copy];

    if (inserted)
        result.alpha = 0;

    if (reloaded) {
        if (!_oldIndexPathKindToDecorationAttributes[indexPathKind])
            result.alpha = 0;
    }

    return [self initialLayoutAttributesForAttributes:result];
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingDecorationElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"kind:%@ indexPath:%@", kind, indexPath);

    AAPLCollectionViewGridLayoutAttributes *result = nil;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSection);

    AAPLDataSourceSectionOperationDirection direction = [_updateSectionDirections[@(section)] intValue];
    if (AAPLDataSourceSectionOperationDirectionNone != direction) {
        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
        return [self finalLayoutAttributesForAttributes:[_oldIndexPathKindToDecorationAttributes[indexPathKind] copy] slidingAwayFromDirection:direction];
    }

    BOOL removed = [self.removedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
    result = [_oldIndexPathKindToDecorationAttributes[indexPathKind] copy];

    if (removed)
        result.alpha = 0;

    if (reloaded) {
        if (!_indexPathKindToDecorationAttributes[indexPathKind])
            result.alpha = 0;
    }

    return [self finalLayoutAttributesForAttributes:result];
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"kind:%@ indexPath:%@", kind, indexPath);

    AAPLCollectionViewGridLayoutAttributes *result = nil;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSection);

    AAPLDataSourceSectionOperationDirection direction = [_updateSectionDirections[@(section)] intValue];
    if (AAPLDataSourceSectionOperationDirectionNone != direction) {
        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
        result = [_indexPathKindToSupplementaryAttributes[indexPathKind] copy];
        if ([AAPLCollectionElementKindPlaceholder isEqualToString:kind]) {
            result.alpha = 0;
            return [self initialLayoutAttributesForAttributes:result];
        }

        return [self initialLayoutAttributesForAttributes:result slidingInFromDirection:direction];
    }

    BOOL inserted = [self.insertedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
    result = [_indexPathKindToSupplementaryAttributes[indexPathKind] copy];

    if (inserted) {
        result.alpha = 0;
        result = [self initialLayoutAttributesForAttributes:result];
    }
    else if (reloaded) {
        if (!_oldIndexPathKindToSupplementaryAttributes[indexPathKind])
            result.alpha = 0;
    }

    return result;
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"kind:%@ indexPath:%@", kind, indexPath);

    AAPLCollectionViewGridLayoutAttributes *result = nil;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSection);

    AAPLDataSourceSectionOperationDirection direction = [_updateSectionDirections[@(section)] intValue];
    if (AAPLDataSourceSectionOperationDirectionNone != direction) {
        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
        result = [_oldIndexPathKindToSupplementaryAttributes[indexPathKind] copy];
        if ([AAPLCollectionElementKindPlaceholder isEqualToString:kind]) {
            result.alpha = 0;
            return [self finalLayoutAttributesForAttributes:result];
        }

        return [self finalLayoutAttributesForAttributes:result slidingAwayFromDirection:direction];
    }

    BOOL removed = [self.removedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:kind];
    result = [_oldIndexPathKindToSupplementaryAttributes[indexPathKind] copy];

    if (removed || reloaded)
        result.alpha = 0;

    return [self finalLayoutAttributesForAttributes:result];
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"indexPath:%@", indexPath);

    AAPLCollectionViewGridLayoutAttributes *result = nil;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSection);

    AAPLDataSourceSectionOperationDirection direction = [_updateSectionDirections[@(section)] intValue];
    if (AAPLDataSourceSectionOperationDirectionNone != direction) {
        return [self initialLayoutAttributesForAttributes:[_indexPathToItemAttributes[indexPath] copy] slidingInFromDirection:direction];
    }

    BOOL inserted = [self.insertedSections containsIndex:section] || [self.insertedIndexPaths containsObject:indexPath];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    result = [_indexPathToItemAttributes[indexPath] copy];

    if (inserted)
        result.alpha = 0;

    if (reloaded) {
        if (!_oldIndexPathToItemAttributes[indexPath])
            result.alpha = 0;
    }

    return [self initialLayoutAttributesForAttributes:result];
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"indexPath:%@", indexPath);

    AAPLCollectionViewGridLayoutAttributes *result = nil;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSection);

    AAPLDataSourceSectionOperationDirection direction = [_updateSectionDirections[@(section)] intValue];
    if (AAPLDataSourceSectionOperationDirectionNone != direction) {
        return [self finalLayoutAttributesForAttributes:[_oldIndexPathToItemAttributes[indexPath] copy] slidingAwayFromDirection:direction];
    }

    BOOL removed = [self.removedIndexPaths containsObject:indexPath] || [self.removedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    result = [_oldIndexPathToItemAttributes[indexPath] copy];

    if (removed)
        result.alpha = 0;

    if (reloaded) {
        // There's no item at this index path, so cross fade
        if (!_indexPathToItemAttributes[indexPath])
            result.alpha = 0;
    }

    return [self finalLayoutAttributesForAttributes:result];
}


#pragma mark - helpers

- (void)updateFlagsFromCollectionView
{
    id dataSource = self.collectionView.dataSource;
    _flags.dataSourceHasSnapshotMetrics = [dataSource respondsToSelector:@selector(snapshotMetrics)];
}

- (AAPLGridLayoutSectionInfo *)sectionInfoForSectionAtIndex:(NSInteger)sectionIndex
{
    return _layoutInfo.sections[@(sectionIndex)];
}

- (NSDictionary *)snapshotMetrics
{
    if (!_flags.dataSourceHasSnapshotMetrics)
        return nil;
    AAPLDataSource *dataSource = (AAPLDataSource *)self.collectionView.dataSource;
    return [dataSource snapshotMetrics];
}

- (void)resetLayoutInfo
{
    if (!_layoutInfo)
        _layoutInfo = [[AAPLGridLayoutInfo alloc] init];
    else
        [_layoutInfo invalidate];

    NSMutableDictionary *tmp;

    tmp = _oldIndexPathKindToSupplementaryAttributes;
    _oldIndexPathKindToSupplementaryAttributes = _indexPathKindToSupplementaryAttributes;
    _indexPathKindToSupplementaryAttributes = tmp;
    [_indexPathKindToSupplementaryAttributes removeAllObjects];

    tmp = _oldIndexPathToItemAttributes;
    _oldIndexPathToItemAttributes = _indexPathToItemAttributes;
    _indexPathToItemAttributes = tmp;
    [_indexPathToItemAttributes removeAllObjects];

    tmp = _oldIndexPathKindToDecorationAttributes;
    _oldIndexPathKindToDecorationAttributes = _indexPathKindToDecorationAttributes;
    _indexPathKindToDecorationAttributes = tmp;
    [_indexPathKindToDecorationAttributes removeAllObjects];
}

- (CGSize)measureSupplementalItemOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionView *collectionView = self.collectionView;
    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;

    UICollectionReusableView *header = [dataSource collectionView:collectionView viewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
    CGSize fittingSize = CGSizeMake(_layoutInfo.width, MEASURE_HEIGHT);
    CGSize size = [header aapl_preferredLayoutSizeFittingSize:fittingSize];
    [header removeFromSuperview];
    return size;
}

/// Create a new section from the metrics.
- (void)createSectionFromMetrics:(AAPLLayoutSectionMetrics *)metrics forSectionAtIndex:(NSInteger)sectionIndex
{
    UICollectionView *collectionView = self.collectionView;
    UIColor *clearColor = [UIColor clearColor];
    CGFloat height = _layoutInfo.height;

    BOOL globalSection = AAPLGlobalSection == sectionIndex;

    CGFloat rowHeight = metrics.rowHeight ?: DEFAULT_ROW_HEIGHT;
    BOOL variableRowHeight = (rowHeight == AAPLRowHeightVariable);
    NSInteger numberOfItemsInSection = (globalSection ? 0 : [collectionView numberOfItemsInSection:sectionIndex]);

    NSAssert(rowHeight != AAPLRowHeightRemainder || numberOfItemsInSection == 1, @"Only one item is permitted in a section with remainder row height.");
    NSAssert(rowHeight != AAPLRowHeightRemainder || sectionIndex == [collectionView numberOfSections] - 1, @"Remainder row height may only be set for last section.");

    if (variableRowHeight)
        rowHeight = MEASURE_HEIGHT;

    AAPLGridLayoutSectionInfo *section = [_layoutInfo addSectionWithIndex:sectionIndex];

    UIColor *separatorColor = metrics.separatorColor;
    UIColor *sectionSeparatorColor = metrics.sectionSeparatorColor;
    UIColor *backgroundColor = metrics.backgroundColor;
    UIColor *selectedBackgroundColor = metrics.selectedBackgroundColor;

    section.backgroundColor = ([backgroundColor isEqual:clearColor] ? nil : backgroundColor);
    section.selectedBackgroundColor = ([selectedBackgroundColor isEqual:clearColor] ? nil : selectedBackgroundColor);
    section.separatorColor = ([separatorColor isEqual:clearColor] ? nil : separatorColor);
    section.sectionSeparatorColor = ([sectionSeparatorColor isEqual:clearColor] ? nil : sectionSeparatorColor);
    section.sectionSeparatorInsets = metrics.sectionSeparatorInsets;
    section.separatorInsets = metrics.separatorInsets;
    section.showsColumnSeparator = metrics.showsColumnSeparator;
    section.showsSectionSeparatorWhenLastSection = metrics.showsSectionSeparatorWhenLastSection;
    section.numberOfColumns = metrics.numberOfColumns ?: 1;
    section.cellLayoutOrder = metrics.cellLayoutOrder;
    section.insets = metrics.padding;

    [metrics.headers enumerateObjectsUsingBlock:^(AAPLLayoutSupplementaryMetrics *headerMetrics, NSUInteger headerIndex, BOOL *stop) {
        AAPLGridLayoutSupplementalItemInfo *header = [section addSupplementalItemAsHeader:YES];
        header.height = headerMetrics.height;
        header.shouldPin = headerMetrics.shouldPin;
        header.visibleWhileShowingPlaceholder = headerMetrics.visibleWhileShowingPlaceholder;
        header.padding = headerMetrics.padding;
        header.hidden = headerMetrics.hidden;

        UIColor *backgroundColor = headerMetrics.backgroundColor;
        if (backgroundColor)
            header.backgroundColor = [backgroundColor isEqual:clearColor] ? nil : backgroundColor;
        else
            header.backgroundColor = section.backgroundColor;

        UIColor *selectedBackgroundColor = headerMetrics.selectedBackgroundColor;
        if (selectedBackgroundColor)
            header.selectedBackgroundColor = [selectedBackgroundColor isEqual:clearColor] ? nil : selectedBackgroundColor;
        else
            header.selectedBackgroundColor = section.selectedBackgroundColor;
    }];

    for (AAPLLayoutSupplementaryMetrics *footerMetrics in metrics.footers) {
        if (!footerMetrics.height)
            continue;
        AAPLGridLayoutSupplementalItemInfo *footer = [section addSupplementalItemAsHeader:NO];
        footer.height = footerMetrics.height;
        footer.backgroundColor = footerMetrics.backgroundColor;
        footer.padding = footerMetrics.padding;
        footer.hidden = footerMetrics.hidden;
    }

    // A section can either have a placeholder or items. Arbitrarily deciding the placeholder takes precedence.
    if (metrics.hasPlaceholder) {
        AAPLGridLayoutSupplementalItemInfo *placeholder = [section addSupplementalItemAsPlaceholder];
        placeholder.height = height;
    }
    else {
        CGFloat columnWidth = section.columnWidth;

        for (NSInteger itemIndex = 0; itemIndex < numberOfItemsInSection; ++itemIndex) {
            AAPLGridLayoutItemInfo *itemInfo = [section addItem];
            itemInfo.frame = CGRectMake(0, 0, columnWidth, rowHeight);
            if (variableRowHeight)
                itemInfo.needSizeUpdate = YES;
        }
    }
}

- (void)createLayoutInfoFromDataSource
{
    LAYOUT_TRACE();

    [self resetLayoutInfo];

    UICollectionView *collectionView = self.collectionView;
    NSDictionary *layoutMetrics = [self snapshotMetrics];
    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;

    UIEdgeInsets contentInset = collectionView.contentInset;
    CGFloat width = CGRectGetWidth(collectionView.bounds) - contentInset.left - contentInset.right;
    CGFloat height = CGRectGetHeight(collectionView.bounds) - contentInset.bottom - contentInset.top;

    NSInteger numberOfSections = [collectionView numberOfSections];

    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        dataSource = nil;

    _layoutInfo.width = width;
    _layoutInfo.height = height;

    LAYOUT_LOG(@"numberOfSections = %ld", (long)numberOfSections);

    AAPLLayoutSectionMetrics *globalMetrics = layoutMetrics[@(AAPLGlobalSection)];
    if (globalMetrics)
        [self createSectionFromMetrics:globalMetrics forSectionAtIndex:AAPLGlobalSection];

    for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
        AAPLLayoutSectionMetrics *metrics = layoutMetrics[@(sectionIndex)];
        [self createSectionFromMetrics:metrics forSectionAtIndex:sectionIndex];
    }
}

- (void)invalidateLayoutForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger sectionIndex = indexPath.section;
    NSInteger itemIndex = indexPath.item;

    AAPLGridLayoutSectionInfo *sectionInfo = [self sectionInfoForSectionAtIndex:sectionIndex];
    AAPLGridLayoutItemInfo *itemInfo = sectionInfo.items[itemIndex];

    UICollectionView *collectionView = self.collectionView;

    // This call really only makes sense if the section has variable height rows…
    CGRect rect = itemInfo.frame;
    CGFloat columnWidth = sectionInfo.columnWidth;
    CGSize fittingSize = CGSizeMake(columnWidth, UILayoutFittingExpandedSize.height);

    // This is really only going to work if it's an AAPLCollectionViewCell, but we'll pretend
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    rect.size = [cell aapl_preferredLayoutSizeFittingSize:fittingSize];
    itemInfo.frame = rect;

    AAPLGridLayoutInvalidationContext *context = [[AAPLGridLayoutInvalidationContext alloc] init];
    context.invalidateLayoutMetrics = YES;
    [self invalidateLayoutWithContext:context];
}

- (void)addLayoutAttributesForSection:(AAPLGridLayoutSectionInfo *)section atIndex:(NSInteger)sectionIndex dataSource:(AAPLDataSource *)dataSource
{
    UICollectionView *collectionView = self.collectionView;
    Class attributeClass = self.class.layoutAttributesClass;

    CGRect sectionFrame = section.frame;

    BOOL globalSection = (AAPLGlobalSection == sectionIndex);

    UIColor *separatorColor = section.separatorColor;
    UIColor *sectionSeparatorColor = section.sectionSeparatorColor;
    NSInteger numberOfItems = [section.items count];

    CGFloat hairline = [[UIScreen mainScreen] scale] > 1 ? 0.5 : 1;

    [section.pinnableHeaderAttributes removeAllObjects];
    [section.nonPinnableHeaderAttributes removeAllObjects];

    if (AAPLGlobalSection == sectionIndex && section.backgroundColor) {
        // Add the background decoration attribute
        NSIndexPath *indexPath = [NSIndexPath indexPathWithIndex:0];
        AAPLCollectionViewGridLayoutAttributes *backgroundAttribute = [attributeClass layoutAttributesForDecorationViewOfKind:AAPLGridLayoutGlobalHeaderBackgroundKind withIndexPath:indexPath];
        // This will be updated by -filterSpecialAttributes
        backgroundAttribute.frame = section.frame;
        backgroundAttribute.unpinnedY = section.frame.origin.y;
        backgroundAttribute.zIndex = DEFAULT_ZINDEX;
        backgroundAttribute.pinnedHeader = NO;
        backgroundAttribute.backgroundColor = section.backgroundColor;
        backgroundAttribute.hidden = NO;
        [_layoutAttributes addObject:backgroundAttribute];

        section.backgroundAttribute = backgroundAttribute;
        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:AAPLGridLayoutGlobalHeaderBackgroundKind];
        _indexPathKindToDecorationAttributes[indexPathKind] = backgroundAttribute;
    }

    [section.headers enumerateObjectsUsingBlock:^(AAPLGridLayoutSupplementalItemInfo *header, NSUInteger headerIndex, BOOL *stop) {
        CGRect headerFrame = header.frame;

        // ignore headers if there are no items and the header isn't a global header
        if (!numberOfItems && !header.visibleWhileShowingPlaceholder)
            return;

        if (!header.height || header.hidden)
            return;

        NSIndexPath *indexPath = globalSection ? [NSIndexPath indexPathWithIndex:headerIndex] : [NSIndexPath indexPathForItem:headerIndex inSection:sectionIndex];
        AAPLCollectionViewGridLayoutAttributes *headerAttribute = [attributeClass layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader withIndexPath:indexPath];
        headerAttribute.frame = headerFrame;
        headerAttribute.unpinnedY = headerFrame.origin.y;
        headerAttribute.zIndex = HEADER_ZINDEX;
        headerAttribute.pinnedHeader = NO;
        headerAttribute.backgroundColor = header.backgroundColor ? : section.backgroundColor;
        headerAttribute.selectedBackgroundColor = header.selectedBackgroundColor;
        headerAttribute.padding = header.padding;
        headerAttribute.editing = _editing;
        headerAttribute.hidden = NO;
        [_layoutAttributes addObject:headerAttribute];

        if (header.shouldPin) {
            [section.pinnableHeaderAttributes addObject:headerAttribute];
            [self.pinnableAttributes addObject:headerAttribute];
        }
        else if (globalSection) {
            [section.nonPinnableHeaderAttributes addObject:headerAttribute];
        }

        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:UICollectionElementKindSectionHeader];
        _indexPathKindToSupplementaryAttributes[indexPathKind] = headerAttribute;
    }];

    AAPLCollectionViewGridLayoutAttributes *lastAttribute = [_layoutAttributes lastObject];
    if (![lastAttribute.representedElementKind isEqualToString:AAPLGridLayoutSectionSeparatorKind] && sectionSeparatorColor && _totalNumberOfItems) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
        AAPLCollectionViewGridLayoutAttributes *separatorAttributes = [attributeClass layoutAttributesForDecorationViewOfKind:AAPLGridLayoutSectionSeparatorKind withIndexPath:indexPath];
        separatorAttributes.frame = CGRectMake(section.sectionSeparatorInsets.left, section.frame.origin.y, CGRectGetWidth(sectionFrame) - section.sectionSeparatorInsets.left - section.sectionSeparatorInsets.right, hairline);
        separatorAttributes.backgroundColor = sectionSeparatorColor;
        separatorAttributes.zIndex = SEPARATOR_ZINDEX;
        [_layoutAttributes addObject:separatorAttributes];

        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:AAPLGridLayoutSectionSeparatorKind];
        _indexPathKindToDecorationAttributes[indexPathKind] = separatorAttributes;
    }

    AAPLGridLayoutSupplementalItemInfo *placeholder = section.placeholder;
    if (placeholder) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
        AAPLCollectionViewGridLayoutAttributes *placeholderAttribute = [attributeClass layoutAttributesForSupplementaryViewOfKind:AAPLCollectionElementKindPlaceholder withIndexPath:indexPath];
        placeholderAttribute.frame = placeholder.frame;
        placeholderAttribute.zIndex = DEFAULT_ZINDEX + 1;
        [_layoutAttributes addObject:placeholderAttribute];

        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:AAPLCollectionElementKindPlaceholder];
        _indexPathKindToSupplementaryAttributes[indexPathKind] = placeholderAttribute;
    }

    NSInteger numberOfColumns = section.numberOfColumns;
    BOOL showsColumnSeparator = (numberOfColumns > 1) && separatorColor && section.showsColumnSeparator;
    __block NSUInteger itemIndex = 0;

    [section.rows enumerateObjectsUsingBlock:^(AAPLGridLayoutRowInfo *row, NSUInteger rowIndex, BOOL *stop) {
        if (![row.items count])
            return;

        CGRect frame = row.frame;

        _totalNumberOfItems++;

        // If there's a separator, add it above the current row…
        if (rowIndex && separatorColor) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:rowIndex inSection:sectionIndex];
            AAPLCollectionViewGridLayoutAttributes *separatorAttributes = [attributeClass layoutAttributesForDecorationViewOfKind:AAPLGridLayoutRowSeparatorKind withIndexPath:indexPath];
            separatorAttributes.frame = CGRectMake(section.separatorInsets.left, row.frame.origin.y, CGRectGetWidth(frame) - section.separatorInsets.left - section.separatorInsets.right, hairline);
            separatorAttributes.backgroundColor = separatorColor;
            separatorAttributes.zIndex = SEPARATOR_ZINDEX;
            [_layoutAttributes addObject:separatorAttributes];

            AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:AAPLGridLayoutRowSeparatorKind];
            _indexPathKindToDecorationAttributes[indexPathKind] = separatorAttributes;
        }

        [row.items enumerateObjectsUsingBlock:^(AAPLGridLayoutItemInfo *item, NSUInteger idx, BOOL *stop) {
            CGRect frame = item.frame;
            NSInteger columnIndex = item.columnIndex;

            if (columnIndex != NSNotFound && columnIndex < numberOfColumns - 1 && showsColumnSeparator) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:rowIndex * numberOfColumns + columnIndex inSection:sectionIndex];
                AAPLCollectionViewGridLayoutAttributes *separatorAttributes = [attributeClass layoutAttributesForDecorationViewOfKind:AAPLGridLayoutColumnSeparatorKind withIndexPath:indexPath];
                CGRect separatorFrame = frame;
                separatorFrame.origin.x = CGRectGetMaxX(frame);
                separatorFrame.size.width = hairline;
                separatorAttributes.frame = separatorFrame;
                separatorAttributes.backgroundColor = separatorColor;
                separatorAttributes.zIndex = SEPARATOR_ZINDEX;
                [_layoutAttributes addObject:separatorAttributes];

                AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:AAPLGridLayoutColumnSeparatorKind];
                _indexPathKindToDecorationAttributes[indexPathKind] = separatorAttributes;
            }

            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:itemIndex++ inSection:sectionIndex];
            AAPLCollectionViewGridLayoutAttributes *newAttribute = [attributeClass layoutAttributesForCellWithIndexPath:indexPath];
            newAttribute.frame = frame;
            newAttribute.zIndex = DEFAULT_ZINDEX;
            newAttribute.backgroundColor = section.backgroundColor;
            newAttribute.selectedBackgroundColor = section.selectedBackgroundColor;
            newAttribute.editing = _editing ? [dataSource collectionView:collectionView canEditItemAtIndexPath:indexPath] : NO;
            newAttribute.movable = _editing ? [dataSource collectionView:collectionView canMoveItemAtIndexPath:indexPath] : NO;
            newAttribute.columnIndex = columnIndex;
            newAttribute.hidden = NO;

            // Drag & Drop
            newAttribute.hidden = item.dragging;

            [_layoutAttributes addObject:newAttribute];

            _indexPathToItemAttributes[indexPath] = newAttribute;
        }];
    }];

    [section.footers enumerateObjectsUsingBlock:^(AAPLGridLayoutSupplementalItemInfo *footer, NSUInteger footerIndex, BOOL *stop) {
        CGRect frame = footer.frame;

        // ignore the footer if there are no items or the footer has no height
        if (!numberOfItems || !footer.height || footer.hidden)
            return;

        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:footerIndex inSection:sectionIndex];
        AAPLCollectionViewGridLayoutAttributes *footerAttribute = [attributeClass layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionFooter withIndexPath:indexPath];
        footerAttribute.frame = frame;
        footerAttribute.zIndex = HEADER_ZINDEX;
        footerAttribute.backgroundColor = footer.backgroundColor ? : section.backgroundColor;
        footerAttribute.selectedBackgroundColor = footer.selectedBackgroundColor;
        footerAttribute.padding = footer.padding;
        footerAttribute.editing = _editing;
        footerAttribute.hidden = NO;
        [_layoutAttributes addObject:footerAttribute];

        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:UICollectionElementKindSectionFooter];
        _indexPathKindToSupplementaryAttributes[indexPathKind] = footerAttribute;
    }];
    
    NSUInteger numberOfSections = [_layoutInfo.sections count];

    // Add the section separator below this section provided it's not the last section (or if the section explicitly says to)
    if (sectionSeparatorColor && _totalNumberOfItems && (sectionIndex +1 < numberOfSections || section.showsSectionSeparatorWhenLastSection)) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:1 inSection:sectionIndex];
        AAPLCollectionViewGridLayoutAttributes *separatorAttributes = [attributeClass layoutAttributesForDecorationViewOfKind:AAPLGridLayoutSectionSeparatorKind withIndexPath:indexPath];
        separatorAttributes.frame = CGRectMake(section.sectionSeparatorInsets.left, CGRectGetMaxY(section.frame), CGRectGetWidth(sectionFrame) - section.sectionSeparatorInsets.left - section.sectionSeparatorInsets.right, hairline);
        separatorAttributes.backgroundColor = sectionSeparatorColor;
        separatorAttributes.zIndex = SEPARATOR_ZINDEX;
        [_layoutAttributes addObject:separatorAttributes];

        AAPLIndexPathKind *indexPathKind = [[AAPLIndexPathKind alloc] initWithIndexPath:indexPath kind:AAPLGridLayoutSectionSeparatorKind];
        _indexPathKindToDecorationAttributes[indexPathKind] = separatorAttributes;
    }
}

- (CGFloat)heightOfAttributes:(NSArray *)attributes
{
    if (![attributes count])
        return 0;

    CGFloat minY = CGFLOAT_MAX;
    CGFloat maxY = CGFLOAT_MIN;

    for (AAPLCollectionViewGridLayoutAttributes *attr in attributes) {
        minY = MIN(minY, CGRectGetMinY(attr.frame));
        maxY = MAX(maxY, CGRectGetMaxY(attr.frame));
    }

    return maxY - minY;
}

- (void)buildLayout
{
    if (_flags.layoutMetricsAreValid)
        return;

    if (_preparingLayout)
        return;

    _preparingLayout = YES;

    LAYOUT_TRACE();

    [self updateFlagsFromCollectionView];

    if (!_flags.layoutDataIsValid) {
        [self createLayoutInfoFromDataSource];
        _flags.layoutDataIsValid = YES;
    }

    UICollectionView *collectionView = self.collectionView;
    UIEdgeInsets contentInset = collectionView.contentInset;

    CGFloat width = CGRectGetWidth(collectionView.bounds) - contentInset.left - contentInset.right;
    CGFloat height = CGRectGetHeight(collectionView.bounds) - contentInset.bottom - contentInset.top;

    _oldLayoutSize = _layoutSize;
    _layoutSize = CGSizeZero;

    _layoutInfo.width = width;
    _layoutInfo.height = height;
    _layoutInfo.contentOffsetY = collectionView.contentOffset.y + contentInset.top;

    CGFloat start = 0;

    [self.layoutAttributes removeAllObjects];
    [self.pinnableAttributes removeAllObjects];
    self.totalNumberOfItems = 0;

    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        dataSource = nil;

    NSUInteger numberOfSections = [collectionView numberOfSections];

    __block BOOL shouldInvalidate = NO;

    CGFloat globalNonPinningHeight = 0;
    AAPLGridLayoutSectionInfo *globalSection = [self sectionInfoForSectionAtIndex:AAPLGlobalSection];
    if (globalSection) {
        [globalSection computeLayoutWithOrigin:start measureItemBlock:nil measureSupplementaryItemBlock:^(NSInteger itemIndex, CGRect frame) {
            NSIndexPath *indexPath = [NSIndexPath indexPathWithIndex:itemIndex];
            shouldInvalidate |= YES;
            return [self measureSupplementalItemOfKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
        }];
        [self addLayoutAttributesForSection:globalSection atIndex:AAPLGlobalSection dataSource:dataSource];
        globalNonPinningHeight = [self heightOfAttributes:globalSection.nonPinnableHeaderAttributes];
    }

    for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
        AAPLCollectionViewGridLayoutAttributes *attributes = [_layoutAttributes lastObject];
        if (attributes)
            start = CGRectGetMaxY(attributes.frame);
        AAPLGridLayoutSectionInfo *section = [self sectionInfoForSectionAtIndex:sectionIndex];
        [section computeLayoutWithOrigin:start measureItemBlock:^(NSInteger itemIndex, CGRect frame) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex];
            return [dataSource collectionView:collectionView sizeFittingSize:frame.size forItemAtIndexPath:indexPath];
        } measureSupplementaryItemBlock:^(NSInteger itemIndex, CGRect frame) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex];
            shouldInvalidate |= YES;
            return [self measureSupplementalItemOfKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
        }];
        [self addLayoutAttributesForSection:section atIndex:sectionIndex dataSource:dataSource];
    }

    AAPLCollectionViewGridLayoutAttributes *attributes = [_layoutAttributes lastObject];
    if (attributes)
        start = CGRectGetMaxY(attributes.frame);

    CGFloat layoutHeight = start;

    if (_layoutInfo.contentOffsetY >= globalNonPinningHeight && layoutHeight - globalNonPinningHeight < height) {
        layoutHeight = height + globalNonPinningHeight;
    }

    _layoutSize = CGSizeMake(width, layoutHeight);

    [self filterSpecialAttributes];

    _flags.layoutMetricsAreValid = YES;
    _preparingLayout = NO;

#if LAYOUT_DEBUGGING
    NSLog(@"layout attributes");
    for (UICollectionViewLayoutAttributes *attr in _layoutAttributes) {
        NSString *type;
        switch (attr.representedElementCategory) {
            case UICollectionElementCategoryCell:
                type = @"CELL";
                break;
            case UICollectionElementCategoryDecorationView:
                type = @"DECORATION";
                break;
            case UICollectionElementCategorySupplementaryView:
                type = @"SUPPLEMENTARY";
                break;
        }
        NSLog(@"  %@ %@ indexPath=%@ frame=%@ hidden=%@", type, (attr.representedElementKind ?:@""), AAPLStringFromNSIndexPath(attr.indexPath), NSStringFromCGRect(attr.frame), AAPLStringFromBOOL(attr.hidden));
    }
#endif

    // If the headers change, we need to invalidate…
    if (shouldInvalidate)
        [self invalidateLayout];
}

- (void)resetPinnableAttributes:(NSArray *)pinnableAttributes
{
    for (AAPLCollectionViewGridLayoutAttributes *attributes in pinnableAttributes) {
        attributes.pinnedHeader = NO;
        CGRect frame = attributes.frame;
        frame.origin.y = attributes.unpinnedY;
        attributes.frame = frame;
    }
}

- (CGFloat)applyBottomPinningToAttributes:(NSArray *)attributes maxY:(CGFloat)maxY
{
    for (AAPLCollectionViewGridLayoutAttributes *attr in [attributes reverseObjectEnumerator]) {
        CGRect frame = attr.frame;
        if (CGRectGetMaxY(frame) < maxY) {
            frame.origin.y = maxY - CGRectGetHeight(frame);
            maxY = frame.origin.y;
        }
        attr.zIndex = PINNED_HEADER_ZINDEX;
        attr.frame = frame;
    }

    return maxY;
}

// pin the attributes starting at minY as long a they don't cross maxY and return the new minY
- (CGFloat)applyTopPinningToAttributes:(NSArray *)attributes minY:(CGFloat)minY
{
    for (AAPLCollectionViewGridLayoutAttributes *attr in attributes) {
        CGRect  attrFrame = attr.frame;
        if (attrFrame.origin.y  < minY) {
            attrFrame.origin.y = minY;
            minY = CGRectGetMaxY(attrFrame);    // we have a new pinning offset
        }
        attr.frame = attrFrame;
    }
    return minY;
}

- (void)finalizePinnedAttributes:(NSArray *)attributes zIndex:(NSInteger)zIndex
{
    [attributes enumerateObjectsUsingBlock:^(AAPLCollectionViewGridLayoutAttributes *attr, NSUInteger attrIndex, BOOL *stop) {
        CGRect frame = attr.frame;
        attr.pinnedHeader = frame.origin.y != attr.unpinnedY;
        NSInteger depth = 1 + attrIndex;
        attr.zIndex = zIndex - depth;
    }];
}

- (AAPLGridLayoutSectionInfo *)firstSectionOverlappingYOffset:(CGFloat)yOffset
{
    __block AAPLGridLayoutSectionInfo *result = nil;

    [_layoutInfo.sections enumerateKeysAndObjectsUsingBlock:^(NSNumber *sectionIndex, AAPLGridLayoutSectionInfo *sectionInfo, BOOL *stop) {
        if (AAPLGlobalSection == [sectionIndex intValue])
            return;

        CGRect frame = sectionInfo.frame;
        if (CGRectGetMinY(frame) <= yOffset && yOffset <= CGRectGetMaxY(frame)) {
            result = sectionInfo;
            *stop = YES;
        }
    }];

    return result;
}

- (void)filterSpecialAttributes
{
    UICollectionView *collectionView = self.collectionView;
    NSInteger numSections = [collectionView numberOfSections];

    if (numSections <= 0 || numSections == NSNotFound)  // bail if we have no sections
        return;

    CGPoint contentOffset;

    if (_flags.useCollectionViewContentOffset)
        contentOffset = collectionView.contentOffset;
    else
        contentOffset = [self targetContentOffsetForProposedContentOffset:collectionView.contentOffset];

    CGFloat pinnableY = contentOffset.y + collectionView.contentInset.top;
    CGFloat nonPinnableY = pinnableY;

    [self resetPinnableAttributes:self.pinnableAttributes];

    // Pin the headers as appropriate
    AAPLGridLayoutSectionInfo *section = [self sectionInfoForSectionAtIndex:AAPLGlobalSection];
    if (section.pinnableHeaderAttributes) {
        pinnableY = [self applyTopPinningToAttributes:section.pinnableHeaderAttributes minY:pinnableY];
        [self finalizePinnedAttributes:section.pinnableHeaderAttributes zIndex:PINNED_HEADER_ZINDEX];
    }

    if (section.nonPinnableHeaderAttributes && [section.nonPinnableHeaderAttributes count]) {
        [self resetPinnableAttributes:section.nonPinnableHeaderAttributes];
        nonPinnableY = [self applyBottomPinningToAttributes:section.nonPinnableHeaderAttributes maxY:nonPinnableY];
        [self finalizePinnedAttributes:section.nonPinnableHeaderAttributes zIndex:PINNED_HEADER_ZINDEX];
    }

    if (section.backgroundAttribute) {
        CGRect frame = section.backgroundAttribute.frame;
        frame.origin.y = MIN(nonPinnableY, collectionView.bounds.origin.y);
        CGFloat bottomY = MAX(CGRectGetMaxY([[section.pinnableHeaderAttributes lastObject] frame]), CGRectGetMaxY([[section.nonPinnableHeaderAttributes lastObject] frame]));
        frame.size.height =  bottomY - frame.origin.y;
        section.backgroundAttribute.frame = frame;
    }

    AAPLGridLayoutSectionInfo *overlappingSection = [self firstSectionOverlappingYOffset:pinnableY];
    if (overlappingSection) {
        [self applyTopPinningToAttributes:overlappingSection.pinnableHeaderAttributes minY:pinnableY];
        [self finalizePinnedAttributes:overlappingSection.pinnableHeaderAttributes zIndex:PINNED_HEADER_ZINDEX - 100];
    };
}

- (AAPLCollectionViewGridLayoutAttributes *)initialLayoutAttributesForAttributes:(AAPLCollectionViewGridLayoutAttributes *)attributes
{
    attributes.frame = CGRectOffset(attributes.frame, -self.contentOffsetDelta.x, -self.contentOffsetDelta.y);;
    return attributes;
}

- (AAPLCollectionViewGridLayoutAttributes *)finalLayoutAttributesForAttributes:(AAPLCollectionViewGridLayoutAttributes *)attributes
{
    CGFloat deltaX = + self.contentOffsetDelta.x;
    CGFloat deltaY = + self.contentOffsetDelta.y;
    CGRect frame = attributes.frame;
    if (attributes.pinnedHeader) {
        CGFloat newY = MAX(attributes.unpinnedY, CGRectGetMinY(frame) + deltaY);
        frame.origin.y = newY;
        frame.origin.x += deltaX;
    }
    else
        frame = CGRectOffset(frame, deltaX, deltaY);

    attributes.frame = frame;
    return attributes;
}

- (AAPLCollectionViewGridLayoutAttributes *)initialLayoutAttributesForAttributes:(AAPLCollectionViewGridLayoutAttributes *)attributes slidingInFromDirection:(AAPLDataSourceSectionOperationDirection)direction
{
    CGRect frame = attributes.frame;
    CGRect cvBounds = self.collectionView.bounds;

    if (direction == AAPLDataSourceSectionOperationDirectionLeft)
        frame.origin.x -= cvBounds.size.width;
    else
        frame.origin.x += cvBounds.size.width;

    attributes.frame = frame;
    return [self initialLayoutAttributesForAttributes:attributes];
}

- (AAPLCollectionViewGridLayoutAttributes *)finalLayoutAttributesForAttributes:(AAPLCollectionViewGridLayoutAttributes *)attributes slidingAwayFromDirection:(AAPLDataSourceSectionOperationDirection)direction
{
    CGRect frame = attributes.frame;
    CGRect cvBounds = self.collectionView.bounds;
    if (direction == AAPLDataSourceSectionOperationDirectionLeft)
        frame.origin.x += cvBounds.size.width;
    else
        frame.origin.x -= cvBounds.size.width;

    attributes.alpha = 0;
    attributes.frame = CGRectOffset(frame, self.contentOffsetDelta.x, self.contentOffsetDelta.y);
    return attributes;
}

#pragma mark - AAPLDataSource delegate methods

- (void)dataSource:(AAPLDataSource *)dataSource didInsertSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    [sections enumerateIndexesUsingBlock:^(NSUInteger sectionIndex, BOOL *stop) {
        _updateSectionDirections[@(sectionIndex)] = @(direction);
    }];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    [sections enumerateIndexesUsingBlock:^(NSUInteger sectionIndex, BOOL *stop) {
        _updateSectionDirections[@(sectionIndex)] = @(direction);
    }];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveSection:(NSInteger)section toSection:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction
{
    _updateSectionDirections[@(section)] = @(direction);
    _updateSectionDirections[@(newSection)] = @(direction);
}

@end
