/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
 */

#import "AAPLCollectionViewLayout_Internal.h"
#import "AAPLLayoutMetrics_Private.h"
#import "AAPLDataSource.h"
#import "AAPLCollectionViewLayoutAttributes_Private.h"
#import "AAPLDebug.h"
#import "AAPLTheme.h"
#import "AAPLShadowRegistrar.h"
#import "AAPLDataSourceMapping.h"

#define LAYOUT_DEBUGGING 0
#define LAYOUT_LOGGING 0
#define LAYOUT_TRACING 0
#define DRAG_LOGGING 0

#if LAYOUT_DEBUGGING
#undef LAYOUT_LOGGING
#define LAYOUT_LOGGING 1
#endif

#if LAYOUT_LOGGING
#undef LAYOUT_TRACING
#define LAYOUT_TRACING 1
#define LAYOUT_LOG(FORMAT, ...) NSLog(@"%@ " FORMAT, NSStringFromSelector(_cmd), __VA_ARGS__)
#else
#define LAYOUT_LOG(...)
#endif

#if LAYOUT_TRACING
#define LAYOUT_TRACE() NSLog(@"%@", NSStringFromSelector(_cmd))
#else
#define LAYOUT_TRACE()
#endif

#if DRAG_LOGGING
#define DRAG_TRACE() NSLog(@"%@", NSStringFromSelector(_cmd))
#define DRAG_LOG(FORMAT, ...) NSLog(@"%@ " FORMAT, NSStringFromSelector(_cmd), __VA_ARGS__)
#else
#define DRAG_TRACE()
#define DRAG_LOG(FORMAT, ...)
#endif


#define DRAG_SHADOW_HEIGHT 19

#define SCROLL_SPEED_MAX_MULTIPLIER 4.0
#define FRAMES_PER_SECOND 60.0


NSString * const AAPLCollectionElementKindRowSeparator = @"AAPLCollectionElementKindRowSeparator";
NSString * const AAPLCollectionElementKindColumnSeparator = @"AAPLCollectionElementKindColumnSeparator";
NSString * const AAPLCollectionElementKindSectionSeparator = @"AAPLCollectionElementKindSectionSeparator";
NSString * const AAPLCollectionElementKindGlobalHeaderBackground = @"AAPLCollectionElementKindGlobalHeaderBackground";

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


@interface AAPLCollectionViewSeparatorView : UICollectionReusableView
@end

@implementation AAPLCollectionViewSeparatorView
- (void)applyLayoutAttributes:(AAPLCollectionViewLayoutAttributes *)layoutAttributes
{
    NSAssert([layoutAttributes isKindOfClass:[AAPLCollectionViewLayoutAttributes class]], @"layout attributes not an instance of AAPLCollectionViewLayoutAttributes");
    self.backgroundColor = layoutAttributes.backgroundColor;
}
@end

@interface AAPLCollectionViewLayout ()
@property (nonatomic) CGSize layoutSize;

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

@property (nonatomic, strong) NSMutableArray *pinnableItems;
@property (nonatomic, strong) AAPLLayoutInfo *layoutInfo;
@property (nonatomic, strong) AAPLLayoutInfo *oldLayoutInfo;

/// A dictionary mapping the section index to the AAPLDataSourceSectionOperationDirection value
@property (nonatomic, strong) NSMutableDictionary *updateSectionDirections;
@property (nonatomic, strong) NSMutableSet *insertedIndexPaths;
@property (nonatomic, strong) NSMutableSet *removedIndexPaths;
@property (nonatomic, strong) NSMutableSet *reloadedIndexPaths;
@property (nonatomic, strong) NSMutableIndexSet *insertedSections;
@property (nonatomic, strong) NSMutableIndexSet *removedSections;
@property (nonatomic, strong) NSMutableIndexSet *reloadedSections;
/// Dictionary of kind to array of index paths for additional index paths to delete during updates
@property (nonatomic, strong) NSMutableDictionary *additionalDeletedIndexPaths;
/// Dictionary of kind to array of index paths for additional index paths to insert during updates
@property (nonatomic, strong) NSMutableDictionary *additionalInsertedIndexPaths;
@property (nonatomic) CGPoint contentOffsetDelta;

#if !SUPPORTS_SELFSIZING
/// A duplicate registry of all the cell & supplementary view class/nibs used in this layout. These will be used to create views while measuring the layout instead of dequeueing reusable views, because that causes consternation in UICollectionView.
@property (nonatomic, strong) AAPLShadowRegistrar *shadowRegistrar;
/// Flag used to lock out multiple calls to -buildLayout which seems to happen when measuring cells and supplementary views.
@property (nonatomic) BOOL buildingLayout;
/// The attributes being currently measured. This allows short-circuiting the lookup in several API methods.
@property (nonatomic, strong) AAPLCollectionViewLayoutAttributes *measuringAttributes;
/// The collection view wrapper used while measuring views.
@property (nonatomic, strong) __kindof UIView *collectionViewWrapper;
#endif

@end

@implementation AAPLCollectionViewLayout {
    struct {
        /// the data source has the snapshot metrics method
        unsigned int dataSourceHasSnapshotMetrics:1;
        /// layout data becomes invalid if the data source changes
        unsigned int layoutDataIsValid:1;
    } _flags;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    [self aapl_commonInitCollectionViewLayout];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self)
        return nil;

    [self aapl_commonInitCollectionViewLayout];
    return self;
}

- (void)aapl_commonInitCollectionViewLayout
{
    [self registerClass:[AAPLCollectionViewSeparatorView class] forDecorationViewOfKind:AAPLCollectionElementKindRowSeparator];
    [self registerClass:[AAPLCollectionViewSeparatorView class] forDecorationViewOfKind:AAPLCollectionElementKindColumnSeparator];
    [self registerClass:[AAPLCollectionViewSeparatorView class] forDecorationViewOfKind:AAPLCollectionElementKindSectionSeparator];
    [self registerClass:[AAPLCollectionViewSeparatorView class] forDecorationViewOfKind:AAPLCollectionElementKindGlobalHeaderBackground];

    _scrollingTriggerEdgeInsets = UIEdgeInsetsMake(100, 100, 100, 100);

    _updateSectionDirections = [NSMutableDictionary dictionary];
    _pinnableItems = [NSMutableArray array];
    _shadowRegistrar = [[AAPLShadowRegistrar alloc] init];
}

#pragma mark - Properties

- (void)setEditing:(BOOL)editing
{
    if (editing == _editing)
        return;

    LAYOUT_LOG(@"editing = %@", AAPLStringFromBOOL(editing));

    _editing = editing;
    _flags.layoutDataIsValid = NO;
    [self invalidateLayout];
}

#pragma mark - Editing helpers

- (BOOL)canEditItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionView *collectionView = self.collectionView;
    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        dataSource = nil;
    return [dataSource collectionView:collectionView canEditItemAtIndexPath:indexPath];
}

- (BOOL)canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionView *collectionView = self.collectionView;
    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        dataSource = nil;
    return [dataSource collectionView:collectionView canMoveItemAtIndexPath:indexPath];
}

#pragma mark - View Measuring

#if !SUPPORTS_SELFSIZING

- (CGSize)measuredSizeForSupplementaryItem:(AAPLLayoutSupplementaryItem *)supplementaryItem
{
    UICollectionView *collectionView = self.collectionViewWrapper;
    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;

    self.measuringAttributes = [supplementaryItem.layoutAttributes copy];
    self.measuringAttributes.hidden = YES;

    UICollectionReusableView *view = [dataSource collectionView:collectionView viewForSupplementaryElementOfKind:supplementaryItem.elementKind atIndexPath:supplementaryItem.indexPath];
    UICollectionViewLayoutAttributes *attributes = [view preferredLayoutAttributesFittingAttributes:self.measuringAttributes];
    [view removeFromSuperview];

    // Allow regeneration of the layout attributes later…
    supplementaryItem.layoutAttributes = nil;
    self.measuringAttributes = nil;

    return attributes.frame.size;
}

- (CGSize)measuredSizeForCell:(AAPLLayoutCell *)cell
{
    UICollectionView *collectionView = self.collectionViewWrapper;
    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;

    self.measuringAttributes = [cell.layoutAttributes copy];
    self.measuringAttributes.hidden = YES;

    UICollectionViewCell *view = [dataSource collectionView:collectionView cellForItemAtIndexPath:cell.indexPath];
    UICollectionViewLayoutAttributes *attributes = [view preferredLayoutAttributesFittingAttributes:self.measuringAttributes];
    [view removeFromSuperview];

    // Allow regeneration of the layout attributes later…
    cell.layoutAttributes = nil;
    self.measuringAttributes = nil;

    return attributes.frame.size;
}

- (CGSize)measuredSizeForPlaceholder:(AAPLLayoutPlaceholder *)placeholderInfo
{
    UICollectionView *collectionView = self.collectionViewWrapper;
    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;

    self.measuringAttributes = [placeholderInfo.layoutAttributes copy];
    self.measuringAttributes.hidden = YES;

    UICollectionReusableView *view = [dataSource collectionView:collectionView viewForSupplementaryElementOfKind:self.measuringAttributes.representedElementKind atIndexPath:placeholderInfo.indexPath];
    UICollectionViewLayoutAttributes *attributes = [view preferredLayoutAttributesFittingAttributes:self.measuringAttributes];
    [view removeFromSuperview];

    // Allow regeneration of the layout attributes later…
    placeholderInfo.layoutAttributes = nil;
    self.measuringAttributes = nil;

    return attributes.frame.size;
}

#endif

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

    AAPLLayoutSection *sectionInfo = [self sectionInfoForSectionAtIndex:indexPath.section];
    AAPLLayoutCell *itemInfo = sectionInfo.items[indexPath.item];
    itemInfo.dragging = YES;

    AAPLCollectionViewLayoutInvalidationContext *context = [[AAPLCollectionViewLayoutInvalidationContext alloc] init];
    [context invalidateItemsAtIndexPaths:@[indexPath]];
    [self invalidateLayoutWithContext:context];

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

    AAPLLayoutSection *sourceSection = [self sectionInfoForSectionAtIndex:_sourceItemIndexPath.section];
    AAPLLayoutSection *destinationSection = [self sectionInfoForSectionAtIndex:_selectedItemIndexPath.section];

    destinationSection.phantomCellIndex = NSNotFound;
    destinationSection.phantomCellSize = CGSizeZero;

    NSInteger fromIndex = _sourceItemIndexPath.item;

    AAPLLayoutCell *item = sourceSection.items[fromIndex];
    item.dragging = NO;

    AAPLCollectionViewLayoutInvalidationContext *context = [[AAPLCollectionViewLayoutInvalidationContext alloc] init];
    [sourceSection layoutWithOrigin:sourceSection.frame.origin.y invalidationContext:context];
    if (destinationSection != sourceSection)
        [destinationSection layoutWithOrigin:destinationSection.frame.origin.y invalidationContext:context];
    [self invalidateLayoutWithContext:context];
}

- (void)endDragging
{
    [_currentView removeFromSuperview];

    AAPLLayoutSection *sourceSection = [self sectionInfoForSectionAtIndex:_sourceItemIndexPath.section];
    AAPLLayoutSection *destinationSection = [self sectionInfoForSectionAtIndex:_selectedItemIndexPath.section];

    destinationSection.phantomCellIndex = NSNotFound;
    destinationSection.phantomCellSize = CGSizeZero;

    NSIndexPath *fromIndexPath = _sourceItemIndexPath;
    NSIndexPath *toIndexPath = _selectedItemIndexPath;

    NSInteger fromIndex = fromIndexPath.item;
    NSInteger toIndex = toIndexPath.item;

    AAPLLayoutCell *item = sourceSection.items[fromIndex];
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

    AAPLCollectionViewLayoutInvalidationContext *context = [[AAPLCollectionViewLayoutInvalidationContext alloc] init];
    [sourceSection layoutWithOrigin:sourceSection.frame.origin.y invalidationContext:context];
    if (destinationSection != sourceSection)
        [destinationSection layoutWithOrigin:destinationSection.frame.origin.y invalidationContext:context];
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
    UIEdgeInsets contentInsets = collectionView.contentInset;

    CGSize insetBoundsSize = CGSizeMake(frameSize.width - contentInsets.left - contentInsets.right, frameSize.height - contentInsets.top - contentInsets.bottom);

    // Need to keep the distance as an integer, because the contentOffset property is automatically rounded. This would cause the view center to begin to diverge from the scrolling and appear to slip away from under the user's finger.
    CGFloat distance = rint(self.scrollingSpeed / FRAMES_PER_SECOND);
    CGPoint translation = CGPointZero;

    switch (direction) {
        case AAPLAutoScrollDirectionUp: {
            distance = -distance;
            CGFloat minY = 0.0f;
            CGFloat posY = (contentOffset.y + contentInsets.top);

            if ((posY + distance) <= minY)
                distance = -posY;

            translation = CGPointMake(0.0f, distance);
            break;
        }

        case AAPLAutoScrollDirectionDown: {
            CGFloat maxY = contentSize.height - insetBoundsSize.height;
            CGFloat posY = (contentOffset.y + contentInsets.top);

            if ((posY + distance) >= maxY)
                distance = maxY - posY;

            translation = CGPointMake(0.0f, distance);
            break;
        }

        case AAPLAutoScrollDirectionLeft: {
            distance = -distance;
            CGFloat minX = 0.0f;
            CGFloat posX = (contentOffset.x + contentInsets.left);

            if ((posX + distance) <= minX) {
                distance = -posX;
            }

            translation = CGPointMake(distance, 0.0f);
            break;
        }

        case AAPLAutoScrollDirectionRight: {
            CGFloat maxX = contentSize.width - insetBoundsSize.width;
            CGFloat posX = (contentOffset.x + contentInsets.left);

            if ((contentOffset.x + distance) >= maxX)
                distance = maxX - posX;

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

    AAPLLayoutSection *oldSection = [self sectionInfoForSectionAtIndex:previousIndexPath.section];
    AAPLLayoutSection *newSection = [self sectionInfoForSectionAtIndex:newIndexPath.section];

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

    if (oldSection != newSection) {
        oldSection.phantomCellIndex = NSNotFound;
        oldSection.phantomCellSize = CGSizeZero;
    }
    newSection.phantomCellIndex = newIndexPath.item;
    newSection.phantomCellSize = _dragCellSize;
    _selectedItemIndexPath = newIndexPath;

    DRAG_LOG(@"newIndexPath = %@ previousIndexPath = %@ phantomCellIndex = %ld", AAPLStringFromNSIndexPath(newIndexPath), AAPLStringFromNSIndexPath(previousIndexPath), (long)newSection.phantomCellIndex);

    AAPLCollectionViewLayoutInvalidationContext *context = [[AAPLCollectionViewLayoutInvalidationContext alloc] init];

    [oldSection layoutWithOrigin:oldSection.frame.origin.y invalidationContext:context];
    if (newSection != oldSection)
        [newSection layoutWithOrigin:newSection.frame.origin.y invalidationContext:context];

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
    return [AAPLCollectionViewLayoutAttributes class];
}

+ (Class)invalidationContextClass
{
    return [AAPLCollectionViewLayoutInvalidationContext class];
}

- (void)invalidateLayoutWithContext:(AAPLCollectionViewLayoutInvalidationContext *)context
{
    NSParameterAssert([context isKindOfClass:[AAPLCollectionViewLayoutInvalidationContext class]]);

    BOOL invalidateDataSourceCounts = context.invalidateDataSourceCounts;
    BOOL invalidateEverything = context.invalidateEverything;

    // The collectionView has changed width, reevaluate the layout…
    if (_layoutInfo.collectionViewSize.width != self.collectionView.bounds.size.width)
        invalidateEverything = YES;

    LAYOUT_LOG(@"invalidateDataSourceCounts = %@ invalidateEverything=%@", (invalidateDataSourceCounts ? @"YES" : @"NO"), (invalidateEverything ? @"YES" : @"NO"));

    if (invalidateEverything)
        _flags.layoutDataIsValid = NO;

    if (_flags.layoutDataIsValid) {
        if (invalidateDataSourceCounts)
            _flags.layoutDataIsValid = NO;
    }

#if !SUPPORTS_SELFSIZING
    /// If the layout data is valid, but we've been asked to update the metrics, do that
    if (_flags.layoutDataIsValid && context.invalidateMetrics) {
        AAPLLayoutInfo *layoutInfo = self.layoutInfo;

        [context.invalidatedSupplementaryIndexPaths enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSArray *supplementaryIndexPaths, BOOL *stop) {

            for (NSIndexPath *indexPath in supplementaryIndexPaths)
                [layoutInfo invalidateMetricsForElementOfKind:kind atIndexPath:indexPath invalidationContext:context];
        }];

        for (NSIndexPath *indexPath in context.invalidatedItemIndexPaths)
            [layoutInfo invalidateMetricsForItemAtIndexPath:indexPath invalidationContext:context];
    }
#endif

#if LAYOUT_LOGGING
    if (context.invalidatedSupplementaryIndexPaths.count) {
        for (NSString *kind in context.invalidatedSupplementaryIndexPaths) {
            NSMutableArray *result = [NSMutableArray array];
            NSArray *kindIndexPaths = context.invalidatedSupplementaryIndexPaths[kind];
            for (NSIndexPath *indexPath in kindIndexPaths)
                [result addObject:AAPLStringFromNSIndexPath(indexPath)];
            LAYOUT_LOG(@"%@: invalidated supplementary indexPaths: %@", kind, [result componentsJoinedByString:@", "]);
        }
    }
#endif

    [super invalidateLayoutWithContext:context];
}

- (void)prepareLayout
{
    LAYOUT_LOG(@"bounds=%@", NSStringFromCGRect(self.collectionView.bounds));
    if (!CGRectIsEmpty(self.collectionView.bounds)) {
        [self buildLayout];
    }

    [super prepareLayout];
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    LAYOUT_LOG(@"rect=%@", NSStringFromCGRect(rect));

    NSMutableArray *result = [NSMutableArray array];

    UICollectionView *collectionView = self.collectionView;
    CGPoint contentOffset = [self targetContentOffsetForProposedContentOffset:collectionView.contentOffset];
    [self updateSpecialItemsWithContentOffset:contentOffset invalidationContext:nil];

    [_layoutInfo enumerateSectionsWithBlock:^(NSInteger sectionIndex, AAPLLayoutSection *sectionInfo, BOOL *stopSections) {
        [sectionInfo enumerateLayoutAttributesWithBlock:^(UICollectionViewLayoutAttributes *layoutAttributes, BOOL *stop) {
            if (CGRectIntersectsRect(layoutAttributes.frame, rect))
                [result addObject:layoutAttributes];
        }];
    }];

#if LAYOUT_DEBUGGING
    for (AAPLCollectionViewLayoutAttributes *attr in result) {
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
    NSInteger sectionIndex = indexPath.section;

    if (sectionIndex < 0 || sectionIndex >= _layoutInfo.numberOfSections)
        return nil;

#if !SUPPORTS_SELFSIZING
    AAPLCollectionViewLayoutAttributes *measuringAttributes = self.measuringAttributes;
    if (measuringAttributes && [measuringAttributes.indexPath isEqual:indexPath]) {
        LAYOUT_LOG(@"indexPath=%@ measuringAttributes=%@", AAPLStringFromNSIndexPath(indexPath), measuringAttributes);
        return measuringAttributes;
    }
#endif

    AAPLCollectionViewLayoutAttributes *attributes = [self.layoutInfo layoutAttributesForCellAtIndexPath:indexPath];
    LAYOUT_LOG(@"indexPath=%@ attributes=%@", AAPLStringFromNSIndexPath(indexPath), attributes);
    NSAssert(attributes != nil, @"We should ALWAYS find layout attributes.");
    return attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
#if !SUPPORTS_SELFSIZING
    AAPLCollectionViewLayoutAttributes *measuringAttributes = self.measuringAttributes;

    if (measuringAttributes && [measuringAttributes.indexPath isEqual:indexPath] && [measuringAttributes.representedElementKind isEqualToString:kind]) {
        LAYOUT_LOG(@"measuringAttributes=%@", measuringAttributes);
        return measuringAttributes;
    }
#endif

    AAPLCollectionViewLayoutAttributes *attributes = [self.layoutInfo layoutAttributesForSupplementaryItemOfKind:kind atIndexPath:indexPath];
    LAYOUT_LOG(@"indexPath=%@ attributes=%@", AAPLStringFromNSIndexPath(indexPath), attributes);
    NSAssert(attributes != nil, @"We should ALWAYS find layout attributes.");
    return attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString*)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_TRACE();

    UICollectionViewLayoutAttributes *attributes = [self.layoutInfo layoutAttributesForDecorationViewOfKind:kind atIndexPath:indexPath];
    NSAssert(attributes != nil, @"We'll crash if we can't find our attributes");
    return attributes;
}

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes
{
    // invalidate if the cell changed height
    return (CGRectGetHeight(preferredAttributes.frame) != CGRectGetHeight(originalAttributes.frame));
}

#if SUPPORTS_SELFSIZING

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes
{
    LAYOUT_LOG(@"originalAttributes=%@ preferredAttributes=%@", originalAttributes, preferredAttributes);

    NSIndexPath *indexPath = preferredAttributes.indexPath;
    CGSize size = preferredAttributes.frame.size;

    AAPLGridLayoutInvalidationContext *context = (AAPLGridLayoutInvalidationContext *)[super invalidationContextForPreferredLayoutAttributes:preferredAttributes withOriginalAttributes:originalAttributes];

    switch (preferredAttributes.representedElementCategory) {
        case UICollectionElementCategoryCell:
            [_layoutInfo setSize:size forItemAtIndexPath:indexPath invalidationContext:context];
            break;

        case UICollectionElementCategorySupplementaryView:
            [_layoutInfo setSize:size forElementOfKind:preferredAttributes.representedElementKind atIndexPath:indexPath invalidationContext:context];
            break;

        default:
            break;
    }

    _layoutSize.height += context.contentSizeAdjustment.height;
    return context;
}

#endif

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds
{
    CGRect bounds = self.collectionView.bounds;
    AAPLCollectionViewLayoutInvalidationContext *context = (AAPLCollectionViewLayoutInvalidationContext *)[super invalidationContextForBoundsChange:newBounds];

    BOOL rotation = CGPointEqualToPoint(bounds.origin, newBounds.origin) && bounds.size.width == newBounds.size.height && bounds.size.height == newBounds.size.width;

    BOOL boundsChanged = (newBounds.origin.x != bounds.origin.x || newBounds.origin.y != bounds.origin.y || newBounds.size.height > _layoutSize.height);
    if (rotation || !boundsChanged)
        return context;

    UICollectionView *collectionView = self.collectionView;
    CGPoint contentOffset = collectionView.contentOffset;

    // Update the contentOffset so the special items will layout correctly.
    contentOffset.y += (newBounds.origin.y - bounds.origin.y);
    contentOffset.x += (newBounds.origin.x - bounds.origin.x);

    [self updateSpecialItemsWithContentOffset:contentOffset invalidationContext:context];

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
        AAPLLayoutSection *globalSection = [self sectionInfoForSectionAtIndex:AAPLGlobalSectionIndex];
        CGFloat globalNonPinnableHeight = globalSection.heightOfNonPinningHeaders;
        CGFloat globalPinnableHeight = CGRectGetHeight(globalSection.frame) - globalNonPinnableHeight;

        AAPLLayoutSection *sectionInfo = [self sectionInfoForSectionAtIndex:firstInsertedIndex];
        CGFloat minY = CGRectGetMinY(sectionInfo.frame);
        if (targetContentOffset.y + globalPinnableHeight > minY) {
            // need to make the section visable
            targetContentOffset.y = MAX(globalNonPinnableHeight, minY - globalPinnableHeight);
        }
    }

    targetContentOffset.y -= insets.top;

    LAYOUT_LOG(@"proposedContentOffset=%@ layoutSize=%@ availableHeight=%g targetContentOffset=%@", NSStringFromCGPoint(proposedContentOffset), NSStringFromCGSize(_layoutSize), availableHeight, NSStringFromCGPoint(targetContentOffset));
    return targetContentOffset;
}

- (CGSize)collectionViewContentSize
{
    LAYOUT_TRACE();
    return _layoutSize;
}

- (void)recordAdditionalInsertedIndexPath:(NSIndexPath *)indexPath forElementOfKind:(NSString *)kind
{
    NSMutableArray *array = self.additionalInsertedIndexPaths[kind];
    if (!array)
        array = self.additionalInsertedIndexPaths[kind] = [NSMutableArray array];

    [array addObject:indexPath];
}

- (void)recordAdditionalDeletedIndexPath:(NSIndexPath *)indexPath forElementOfKind:(NSString *)kind
{
    NSMutableArray *array = self.additionalDeletedIndexPaths[kind];
    if (!array)
        array = self.additionalDeletedIndexPaths[kind] = [NSMutableArray array];

    [array addObject:indexPath];
}

- (void)prepareForCollectionViewUpdates:(NSArray *)updateItems
{
    LAYOUT_TRACE();
    self.insertedIndexPaths = [NSMutableSet set];
    self.removedIndexPaths = [NSMutableSet set];
    self.reloadedIndexPaths = [NSMutableSet set];
    self.insertedSections = [NSMutableIndexSet indexSet];
    self.removedSections = [NSMutableIndexSet indexSet];
    self.reloadedSections = [NSMutableIndexSet indexSet];
    self.additionalDeletedIndexPaths = [NSMutableDictionary dictionary];
    self.additionalInsertedIndexPaths = [NSMutableDictionary dictionary];

    for (UICollectionViewUpdateItem *updateItem in updateItems) {
        if (UICollectionUpdateActionInsert == updateItem.updateAction) {
            NSIndexPath *indexPath = updateItem.indexPathAfterUpdate;
            if (indexPath.length > 1 && NSNotFound == indexPath.item)
                [self.insertedSections addIndex:indexPath.section];
            else
                [self.insertedIndexPaths addObject:indexPath];
        }
        else if (UICollectionUpdateActionDelete == updateItem.updateAction) {
            NSIndexPath *indexPath = updateItem.indexPathBeforeUpdate;
            if (indexPath.length > 1 && NSNotFound == indexPath.item)
                [self.removedSections addIndex:indexPath.section];
            else {
                // Deleting extra stuff is handled by UICollectionViewLayout for sections, but not items. So we need to do it ourselves. The only extra layout attributes generated by a row is its separator, but we only need to delete that if it's present and the item was the only one in the row. Note, this doesn't mean 1 column, because we could have one item in a row when it's an odd item in a two column grid.
                AAPLLayoutSection *sectionInfo = [_oldLayoutInfo sectionAtIndex:indexPath.section];
                if (sectionInfo.showsRowSeparator) {
                    AAPLLayoutCell *itemInfo = sectionInfo.items[indexPath.item];
                    AAPLLayoutRow *rowInfo = itemInfo.row;
                    UICollectionViewLayoutAttributes *layoutAttributes = rowInfo.rowSeparatorLayoutAttributes;
                    if (rowInfo.items.count == 1 && layoutAttributes) {
                        [self recordAdditionalDeletedIndexPath:layoutAttributes.indexPath forElementOfKind:layoutAttributes.representedElementKind];
                    }
                }
                [self.removedIndexPaths addObject:indexPath];
            }
        }
        else if (UICollectionUpdateActionReload == updateItem.updateAction) {
            NSIndexPath *indexPath = updateItem.indexPathAfterUpdate;
            if (indexPath.length > 1 && NSNotFound == indexPath.item)
                [self.reloadedSections addIndex:indexPath.section];
            else
                [self.reloadedIndexPaths addObject:indexPath];
        }
        else if (UICollectionUpdateActionMove == updateItem.updateAction) {
            NSIndexPath *oldIndexPath = updateItem.indexPathBeforeUpdate;
            NSIndexPath *newIndexPath = updateItem.indexPathAfterUpdate;
            if (oldIndexPath.length > 1 && NSNotFound == oldIndexPath.item) {
                [self.removedSections addIndex:oldIndexPath.section];
                [self.insertedSections addIndex:newIndexPath.section];
            }
            else {
                // When moving an item OUT of a row, if it was the last element, we should remove the row separator.
                AAPLLayoutSection *sectionInfo = [_oldLayoutInfo sectionAtIndex:oldIndexPath.section];
                if (sectionInfo.showsRowSeparator) {
                    AAPLLayoutCell *itemInfo = sectionInfo.items[oldIndexPath.item];
                    AAPLLayoutRow *rowInfo = itemInfo.row;
                    UICollectionViewLayoutAttributes *layoutAttributes = rowInfo.rowSeparatorLayoutAttributes;
                    if (rowInfo.items.count == 1 && layoutAttributes) {
                        [self recordAdditionalDeletedIndexPath:layoutAttributes.indexPath forElementOfKind:layoutAttributes.representedElementKind];
                    }
                }
            }
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
    self.oldLayoutInfo = nil;
    self.additionalDeletedIndexPaths = nil;
    self.additionalInsertedIndexPaths = nil;

    [self.updateSectionDirections removeAllObjects];
}

// These methods are called by collection view during an update block.
// Return an array of index paths to indicate views that the layout is deleting or inserting in response to the update.
//- (NSArray *)indexPathsToDeleteForSupplementaryViewOfKind:(NSString *)kind
//{
//    NSArray *indexPaths = [super indexPathsToDeleteForSupplementaryViewOfKind:kind];
//    NSLog(@"indexPathsToDeleteForSupplementaryViewOfKind: %@ => %@", kind, indexPaths);
//    return indexPaths;
//}

- (NSArray *)indexPathsToDeleteForDecorationViewOfKind:(NSString *)kind
{
    NSArray *superValue = [super indexPathsToDeleteForDecorationViewOfKind:kind];
    NSArray *additionalValues = self.additionalDeletedIndexPaths[kind];
    if (additionalValues) {
        LAYOUT_LOG(@"kind=%@ value=%@", kind, additionalValues);
        return [superValue arrayByAddingObjectsFromArray:additionalValues];
    }
    LAYOUT_LOG(@"kind=%@ value=%@", kind, superValue);
    return superValue;
}


//- (NSArray *)indexPathsToInsertForSupplementaryViewOfKind:(NSString *)kind
//{
//    NSArray *indexPaths = [super indexPathsToInsertForSupplementaryViewOfKind:kind];
//    NSLog(@"indexPathsToInsertForSupplementaryViewOfKind: %@ => %@", kind, indexPaths);
//    return indexPaths;
//}

//- (NSArray *)indexPathsToInsertForDecorationViewOfKind:(NSString *)kind
//{
//}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingDecorationElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"kind=%@ indexPath=%@", kind, AAPLStringFromNSIndexPath(indexPath));

    AAPLCollectionViewLayoutAttributes *result = [[self.layoutInfo layoutAttributesForDecorationViewOfKind:kind atIndexPath:indexPath] copy];
    if (!result)
        return result;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex);

    AAPLDataSourceSectionOperationDirection direction = [self operationDirectionForSectionAtIndex:section];
    if (AAPLDataSourceSectionOperationDirectionNone != direction)
        return [self initialLayoutAttributesForAttributes:result slidingInFromDirection:direction];

    BOOL inserted = [self.insertedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    if (inserted)
        result.alpha = 0;

    if (reloaded) {
        if (![self.oldLayoutInfo layoutAttributesForDecorationViewOfKind:kind atIndexPath:indexPath])
            result.alpha = 0;
    }

    return [self initialLayoutAttributesForAttributes:result];
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingDecorationElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"kind=%@ indexPath=%@", kind, AAPLStringFromNSIndexPath(indexPath));

    AAPLCollectionViewLayoutAttributes *result = [[self.oldLayoutInfo layoutAttributesForDecorationViewOfKind:kind atIndexPath:indexPath] copy];;
    if (!result)
        return result;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex);

    AAPLDataSourceSectionOperationDirection direction = [self operationDirectionForSectionAtIndex:section];
    if (AAPLDataSourceSectionOperationDirectionNone != direction)
        return [self finalLayoutAttributesForAttributes:result slidingAwayFromDirection:direction];

    BOOL removed = [self.removedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    if (removed)
        result.alpha = 0;

    if (reloaded) {
        if (![self.layoutInfo layoutAttributesForDecorationViewOfKind:kind atIndexPath:indexPath])
            result.alpha = 0;
    }

    return [self finalLayoutAttributesForAttributes:result];
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"kind=%@ indexPath=%@", kind, AAPLStringFromNSIndexPath(indexPath));

    AAPLCollectionViewLayoutAttributes *result = [[self.layoutInfo layoutAttributesForSupplementaryItemOfKind:kind atIndexPath:indexPath] copy];
    if (!result)
        return result;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex);

    AAPLDataSourceSectionOperationDirection direction = [self operationDirectionForSectionAtIndex:section];
    if (AAPLDataSourceSectionOperationDirectionNone != direction) {
        if ([AAPLCollectionElementKindPlaceholder isEqualToString:kind]) {
            result.alpha = 0;
            return [self initialLayoutAttributesForAttributes:result];
        }

        return [self initialLayoutAttributesForAttributes:result slidingInFromDirection:direction];
    }

    BOOL inserted = [self.insertedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    if (inserted) {
        result.alpha = 0;
        result = [self initialLayoutAttributesForAttributes:result];
    }
    else if (reloaded) {
        if (![self.oldLayoutInfo layoutAttributesForSupplementaryItemOfKind:kind atIndexPath:indexPath])
            result.alpha = 0;
    }

    return result;
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"kind=%@ indexPath=%@", kind, AAPLStringFromNSIndexPath(indexPath));

    AAPLCollectionViewLayoutAttributes *result = [[self.oldLayoutInfo layoutAttributesForSupplementaryItemOfKind:kind atIndexPath:indexPath] copy];
    if (!result)
        return result;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex);

    AAPLDataSourceSectionOperationDirection direction = [self operationDirectionForSectionAtIndex:section];
    if (AAPLDataSourceSectionOperationDirectionNone != direction) {
        if ([AAPLCollectionElementKindPlaceholder isEqualToString:kind]) {
            result.alpha = 0;
            return [self finalLayoutAttributesForAttributes:result];
        }

        return [self finalLayoutAttributesForAttributes:result slidingAwayFromDirection:direction];
    }

    BOOL removed = [self.removedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    if (removed || reloaded)
        result.alpha = 0;

    return [self finalLayoutAttributesForAttributes:result];
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"indexPath=%@", AAPLStringFromNSIndexPath(indexPath));

    AAPLCollectionViewLayoutAttributes *result = [[self.layoutInfo layoutAttributesForCellAtIndexPath:indexPath] copy];
    if (!result)
        return result;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex);

    AAPLDataSourceSectionOperationDirection direction = [self operationDirectionForSectionAtIndex:section];
    if (AAPLDataSourceSectionOperationDirectionNone != direction)
        return [self initialLayoutAttributesForAttributes:result slidingInFromDirection:direction];

    BOOL inserted = [self.insertedSections containsIndex:section] || [self.insertedIndexPaths containsObject:indexPath];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    if (inserted)
        result.alpha = 0;

    if (reloaded) {
        if (![self.oldLayoutInfo layoutAttributesForCellAtIndexPath:indexPath])
            result.alpha = 0;
    }

    result = [self initialLayoutAttributesForAttributes:result];
    LAYOUT_LOG(@"frame=%@", NSStringFromCGRect(result.frame));
    return result;
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)indexPath
{
    LAYOUT_LOG(@"indexPath=%@", AAPLStringFromNSIndexPath(indexPath));

    AAPLCollectionViewLayoutAttributes *result = [[self.oldLayoutInfo layoutAttributesForCellAtIndexPath:indexPath] copy];
    if (!result)
        return result;

    NSInteger section = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex);

    AAPLDataSourceSectionOperationDirection direction = [self operationDirectionForSectionAtIndex:section];
    if (AAPLDataSourceSectionOperationDirectionNone != direction)
        return [self finalLayoutAttributesForAttributes:result slidingAwayFromDirection:direction];

    BOOL deletedItem = [self.removedIndexPaths containsObject:indexPath];
    BOOL removed = [self.removedSections containsIndex:section];
    BOOL reloaded = [self.reloadedSections containsIndex:section];

    if (removed || deletedItem)
        result.alpha = 0;

    if (reloaded) {
        // There's no item at this index path, so cross fade
        if (![self.layoutInfo layoutAttributesForCellAtIndexPath:indexPath])
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

- (AAPLDataSourceSectionOperationDirection)operationDirectionForSectionAtIndex:(NSInteger)sectionIndex
{
    if (UIAccessibilityIsReduceMotionEnabled())
        return AAPLDataSourceSectionOperationDirectionNone;
    return [_updateSectionDirections[@(sectionIndex)] intValue];
}

- (AAPLLayoutSection *)sectionInfoForSectionAtIndex:(NSInteger)sectionIndex
{
    return [_layoutInfo sectionAtIndex:sectionIndex];
}

- (NSDictionary<NSNumber *, AAPLDataSourceSectionMetrics *> *)snapshotMetrics
{
    if (!_flags.dataSourceHasSnapshotMetrics)
        return nil;
    AAPLDataSource *dataSource = (AAPLDataSource *)self.collectionView.dataSource;
    return [dataSource snapshotMetrics];
}

- (void)resetLayoutInfo
{
    _oldLayoutInfo = _layoutInfo;
    _layoutInfo = [[AAPLLayoutInfo alloc] initWithLayout:self];
}

- (void)createLayoutInfoFromDataSource
{
    [self resetLayoutInfo];

    UICollectionView *collectionView = self.collectionView;
    NSDictionary<NSNumber *, AAPLDataSourceSectionMetrics *> *layoutMetrics = [self snapshotMetrics];

    UIEdgeInsets contentInset = collectionView.contentInset;
    CGFloat width = CGRectGetWidth(collectionView.bounds) - contentInset.left - contentInset.right;
    CGFloat height = CGRectGetHeight(collectionView.bounds) - contentInset.bottom - contentInset.top;

    NSInteger numberOfSections = [collectionView numberOfSections];

    _layoutInfo.collectionViewSize = collectionView.bounds.size;
    _layoutInfo.width = width;
    _layoutInfo.height = height;

    LAYOUT_LOG(@"numberOfSections = %ld", (long)numberOfSections);

    AAPLDataSourceSectionMetrics *globalMetrics = layoutMetrics[@(AAPLGlobalSectionIndex)];
    if (globalMetrics) {
        AAPLLayoutSection *sectionInfo = [_layoutInfo newSectionWithIndex:AAPLGlobalSectionIndex];
        [self populateSection:sectionInfo fromMetrics:globalMetrics];
    }

    id placeholder = nil;
    AAPLLayoutPlaceholder *placeholderInfo = nil;

    for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
        AAPLDataSourceSectionMetrics *metrics = layoutMetrics[@(sectionIndex)];
        AAPLLayoutSection *sectionInfo = [_layoutInfo newSectionWithIndex:sectionIndex];

        if (metrics.placeholder) {
            if (metrics.placeholder != placeholder) {
                placeholderInfo = [_layoutInfo newPlaceholderStartingAtSectionIndex:sectionIndex];
                placeholderInfo.height = 200;
                placeholderInfo.hasEstimatedHeight = YES;
            }

            sectionInfo.placeholderInfo = placeholderInfo;
        }
        else
            placeholderInfo = nil;

        placeholder = metrics.placeholder;

        [self populateSection:sectionInfo fromMetrics:metrics];
    }
}

/// Create a new section from the metrics.
- (void)populateSection:(AAPLLayoutSection *)section fromMetrics:(AAPLDataSourceSectionMetrics *)metrics
{
    NSInteger sectionIndex = section.sectionIndex;

    UICollectionView *collectionView = self.collectionView;

    BOOL globalSection = AAPLGlobalSectionIndex == sectionIndex;

    CGFloat estimatedRowHeight = metrics.estimatedRowHeight;
    CGFloat rowHeight = metrics.rowHeight;
    BOOL variableRowHeight = (rowHeight == AAPLCollectionViewAutomaticHeight);
    NSInteger numberOfItemsInSection = (globalSection ? 0 : [collectionView numberOfItemsInSection:sectionIndex]);

    if (variableRowHeight)
        rowHeight = estimatedRowHeight;

    // Ensure that the section is empty and ready to be populated
    [section reset];
    [section applyValuesFromMetrics:metrics];
    [section resolveMissingValuesFromTheme];

    void (^setupSupplementaryMetrics)(id obj, NSUInteger idx, BOOL *stop) = ^(AAPLSupplementaryItem *supplementaryMetrics, NSUInteger headerIndex, BOOL *stop) {

        AAPLLayoutSupplementaryItem *supplementaryItem = [[AAPLLayoutSupplementaryItem alloc] initWithElementKind:supplementaryMetrics.elementKind];
        [supplementaryItem applyValuesFromMetrics:supplementaryMetrics];
        [section addSupplementaryItem:supplementaryItem];
    };

    [metrics.headers enumerateObjectsUsingBlock:setupSupplementaryMetrics];
    [metrics.footers enumerateObjectsUsingBlock:setupSupplementaryMetrics];

    LAYOUT_LOG(@"section %ld:   numberOfItems=%ld hasPlaceholder=%@", (long)sectionIndex, (long)numberOfItemsInSection, (metrics.placeholder ? @"YES" : @"NO"));

    CGFloat columnWidth = section.columnWidth;

    for (NSInteger itemIndex = 0; itemIndex < numberOfItemsInSection; ++itemIndex) {
        AAPLLayoutCell *itemInfo = [[AAPLLayoutCell alloc] init];
        itemInfo.frame = CGRectMake(0, 0, columnWidth, rowHeight);
        if (variableRowHeight)
            itemInfo.hasEstimatedHeight = YES;
        [section addItem:itemInfo];
    }
}

- (void)buildLayout
{
    if (_flags.layoutDataIsValid)
        return;

#if !SUPPORTS_SELFSIZING
    if (_buildingLayout)
        return;
    _buildingLayout = YES;
    // Create the collection view wrapper that will be used for measuring.
    self.collectionViewWrapper = [AAPLCollectionViewWrapper wrapperForCollectionView:self.collectionView mapping:nil measuring:YES];
#endif

    LAYOUT_TRACE();

    [self updateFlagsFromCollectionView];

    [self createLayoutInfoFromDataSource];
    _flags.layoutDataIsValid = YES;


    UICollectionView *collectionView = self.collectionView;
    UIEdgeInsets contentInset = collectionView.contentInset;

    CGFloat width = CGRectGetWidth(collectionView.bounds) - contentInset.left - contentInset.right;
    CGFloat height = CGRectGetHeight(collectionView.bounds) - contentInset.bottom - contentInset.top;

    _layoutSize = CGSizeZero;

    _layoutInfo.width = width;
    _layoutInfo.height = height;
    _layoutInfo.contentOffsetY = collectionView.contentOffset.y + contentInset.top;

    CGFloat start = 0;

    [self.pinnableItems removeAllObjects];

    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        dataSource = nil;

    NSInteger numberOfSections = (NSInteger)[collectionView numberOfSections];

    CGFloat globalNonPinningHeight = 0;
    AAPLLayoutSection *globalSection = [self sectionInfoForSectionAtIndex:AAPLGlobalSectionIndex];
    if (globalSection) {
        start = [globalSection layoutWithOrigin:start invalidationContext:nil];
        globalNonPinningHeight = [globalSection heightOfNonPinningHeaders];
    }

    for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
        AAPLLayoutSection *section = [self sectionInfoForSectionAtIndex:sectionIndex];
        start = [section layoutWithOrigin:start invalidationContext:nil];
    }

    CGFloat layoutHeight = start;

    // The layoutHeight is the total height of the layout including any placeholders in their default size. Determine how much space is left to be shared out among the placeholders
    _layoutInfo.heightAvailableForPlaceholders = MAX(0, height - layoutHeight);

    if (_layoutInfo.contentOffsetY >= globalNonPinningHeight && layoutHeight - globalNonPinningHeight < height) {
        layoutHeight = height + globalNonPinningHeight;
    }

    _layoutSize = CGSizeMake(width, layoutHeight);

    CGPoint contentOffset = [self targetContentOffsetForProposedContentOffset:collectionView.contentOffset];
    [self updateSpecialItemsWithContentOffset:contentOffset invalidationContext:nil];


    [_layoutInfo finalizeLayout];

#if !SUPPORTS_SELFSIZING
    self.collectionViewWrapper = nil;

    LAYOUT_LOG(@"Final layout height: %g", layoutHeight);
    _buildingLayout = NO;
#endif

}

- (void)resetPinnableSupplementaryItems:(NSArray *)supplementaryItems invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    for (AAPLLayoutSupplementaryItem *supplementaryItem in supplementaryItems) {
        AAPLCollectionViewLayoutAttributes *attributes = supplementaryItem.layoutAttributes;
        CGRect frame = attributes.frame;

        if (frame.origin.y != attributes.unpinnedY)
            [invalidationContext invalidateSupplementaryElementsOfKind:attributes.representedElementKind atIndexPaths:@[attributes.indexPath]];

        attributes.pinnedHeader = NO;
        frame.origin.y = attributes.unpinnedY;
        attributes.frame = frame;
    }
}

- (CGFloat)applyBottomPinningToSupplementaryItems:(NSArray *)supplementaryItems maxY:(CGFloat)maxY invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    for (AAPLLayoutSupplementaryItem *supplementaryItem in [supplementaryItems reverseObjectEnumerator]) {
        AAPLCollectionViewLayoutAttributes *layoutAttributes = supplementaryItem.layoutAttributes;
        CGRect frame = layoutAttributes.frame;

        if (CGRectGetMaxY(frame) < maxY) {
            frame.origin.y = maxY - CGRectGetHeight(frame);
            maxY = frame.origin.y;
            layoutAttributes.frame = frame;

            [invalidationContext invalidateSupplementaryElementsOfKind:layoutAttributes.representedElementKind atIndexPaths:@[layoutAttributes.indexPath]];
        }
    }

    return maxY;
}

// pin the attributes starting at minY as long a they don't cross maxY and return the new minY
- (CGFloat)applyTopPinningToSupplementaryItems:(NSArray *)supplementaryItems minY:(CGFloat)originalMinY invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    __block CGFloat minY = originalMinY;

    [supplementaryItems enumerateObjectsUsingBlock:^(AAPLLayoutSupplementaryItem *supplementaryItem, NSUInteger itemIndex, BOOL *stop) {

        // Record this supplementary item so we can reset it later
        [self.pinnableItems addObject:supplementaryItem];

        AAPLCollectionViewLayoutAttributes *layoutAttributes = supplementaryItem.layoutAttributes;
        CGRect frame = layoutAttributes.frame;

        if (frame.origin.y < minY) {
            frame.origin.y = minY;
            minY = CGRectGetMaxY(frame);    // we have a new pinning offset
            layoutAttributes.frame = frame;

            [invalidationContext invalidateSupplementaryElementsOfKind:layoutAttributes.representedElementKind atIndexPaths:@[layoutAttributes.indexPath]];
        }
    }];

    return minY;
}

- (void)finalizePinningForSupplementaryItems:(NSArray *)supplementaryItems zIndex:(NSInteger)zIndex
{
    [supplementaryItems enumerateObjectsUsingBlock:^(AAPLLayoutSupplementaryItem *supplementaryItem, NSUInteger itemIndex, BOOL *stop) {
        AAPLCollectionViewLayoutAttributes *layoutAttributes = supplementaryItem.layoutAttributes;

        CGRect frame = layoutAttributes.frame;
        layoutAttributes.pinnedHeader = frame.origin.y != layoutAttributes.unpinnedY;
        NSInteger depth = 1 + itemIndex;
        layoutAttributes.zIndex = zIndex - depth;
    }];
}

- (AAPLLayoutSection *)firstSectionOverlappingYOffset:(CGFloat)yOffset
{
    __block AAPLLayoutSection *result = nil;

    [_layoutInfo enumerateSectionsWithBlock:^(NSInteger sectionIndex, AAPLLayoutSection *sectionInfo, BOOL *stop) {
        if (AAPLGlobalSectionIndex == sectionIndex)
            return;

        CGRect frame = sectionInfo.frame;
        if (CGRectGetMinY(frame) <= yOffset && yOffset <= CGRectGetMaxY(frame)) {
            result = sectionInfo;
            *stop = YES;
        }
    }];

    return result;
}

- (void)updateSpecialItemsWithContentOffset:(CGPoint)contentOffset invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    UICollectionView *collectionView = self.collectionView;
    NSInteger numSections = [collectionView numberOfSections];

    if (numSections <= 0 || numSections == NSNotFound)  // bail if we have no sections
        return;

    CGFloat pinnableY = contentOffset.y + collectionView.contentInset.top;
    CGFloat nonPinnableY = pinnableY;

    [self resetPinnableSupplementaryItems:self.pinnableItems invalidationContext:invalidationContext];
    [self.pinnableItems removeAllObjects];

    // Pin the headers as appropriate
    AAPLLayoutSection *section = [self sectionInfoForSectionAtIndex:AAPLGlobalSectionIndex];
    if (section.pinnableHeaders) {
        pinnableY = [self applyTopPinningToSupplementaryItems:section.pinnableHeaders minY:pinnableY invalidationContext:invalidationContext];
        [self finalizePinningForSupplementaryItems:section.pinnableHeaders zIndex:PINNED_HEADER_ZINDEX];
    }

    if (section.nonPinnableHeaders && section.nonPinnableHeaders.count) {
        [self resetPinnableSupplementaryItems:section.nonPinnableHeaders invalidationContext:invalidationContext];
        nonPinnableY = [self applyBottomPinningToSupplementaryItems:section.nonPinnableHeaders maxY:nonPinnableY invalidationContext:invalidationContext];
        [self finalizePinningForSupplementaryItems:section.nonPinnableHeaders zIndex:PINNED_HEADER_ZINDEX];
    }

    if (section.backgroundAttribute) {
        CGRect frame = section.backgroundAttribute.frame;
        frame.origin.y = MIN(nonPinnableY, collectionView.bounds.origin.y);
        CGFloat bottomY = MAX(CGRectGetMaxY([section.pinnableHeaders.lastObject frame]), CGRectGetMaxY([section.nonPinnableHeaders.lastObject frame]));
        frame.size.height =  bottomY - frame.origin.y;
        section.backgroundAttribute.frame = frame;
    }

    AAPLLayoutSection *overlappingSection = [self firstSectionOverlappingYOffset:pinnableY];
    if (overlappingSection) {
        [self applyTopPinningToSupplementaryItems:overlappingSection.pinnableHeaders minY:pinnableY invalidationContext:invalidationContext];
        [self finalizePinningForSupplementaryItems:overlappingSection.pinnableHeaders zIndex:PINNED_HEADER_ZINDEX - 100];
    };
}

- (AAPLCollectionViewLayoutAttributes *)initialLayoutAttributesForAttributes:(AAPLCollectionViewLayoutAttributes *)attributes
{
    attributes.frame = CGRectOffset(attributes.frame, -self.contentOffsetDelta.x, -self.contentOffsetDelta.y);;
    NSAssert(attributes != nil, @"Shouldn't have nil attributes");
    return attributes;
}

- (AAPLCollectionViewLayoutAttributes *)finalLayoutAttributesForAttributes:(AAPLCollectionViewLayoutAttributes *)attributes
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
    NSAssert(attributes != nil, @"Shouldn't have nil attributes");
    return attributes;
}

- (AAPLCollectionViewLayoutAttributes *)initialLayoutAttributesForAttributes:(AAPLCollectionViewLayoutAttributes *)attributes slidingInFromDirection:(AAPLDataSourceSectionOperationDirection)direction
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

- (AAPLCollectionViewLayoutAttributes *)finalLayoutAttributesForAttributes:(AAPLCollectionViewLayoutAttributes *)attributes slidingAwayFromDirection:(AAPLDataSourceSectionOperationDirection)direction
{
    CGRect frame = attributes.frame;
    CGRect cvBounds = self.collectionView.bounds;
    if (direction == AAPLDataSourceSectionOperationDirectionLeft)
        frame.origin.x += cvBounds.size.width;
    else
        frame.origin.x -= cvBounds.size.width;
    
    attributes.alpha = 0;
    attributes.frame = CGRectOffset(frame, self.contentOffsetDelta.x, self.contentOffsetDelta.y);
    NSAssert(attributes != nil, @"Shouldn't have nil attributes");
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
