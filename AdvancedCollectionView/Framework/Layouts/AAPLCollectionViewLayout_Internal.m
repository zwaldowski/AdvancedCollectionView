/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
 
  This file contains implementations of the internal classes used by AAPLCollectionViewGridLayout to build the layout.
 */

#import "AAPLCollectionViewLayout_Internal.h"
#import "UICollectionView+SupplementaryViews.h"
#import "AAPLLayoutMetrics_Private.h"

static void AAPLInvalidateLayoutAttributes(UICollectionViewLayoutInvalidationContext *invalidationContext, UICollectionViewLayoutAttributes *attributes)
{
    NSArray *indexPaths = @[attributes.indexPath];

    switch (attributes.representedElementCategory) {
        case UICollectionElementCategoryCell:
            [invalidationContext invalidateItemsAtIndexPaths:indexPaths];
            break;

        case UICollectionElementCategoryDecorationView:
            [invalidationContext invalidateDecorationElementsOfKind:attributes.representedElementKind atIndexPaths:indexPaths];
            break;

        case UICollectionElementCategorySupplementaryView:
            [invalidationContext invalidateSupplementaryElementsOfKind:attributes.representedElementKind atIndexPaths:indexPaths];
            break;
    }
}


@implementation AAPLCollectionViewLayoutInvalidationContext
@end

@interface AAPLLayoutInfo ()
@property (nonatomic, strong) AAPLLayoutSection *globalSection;
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic) NSInteger numberOfPlaceholders;
@property (nonatomic, weak) AAPLCollectionViewLayout *layout;
@end

@interface AAPLLayoutPlaceholder ()
@property (nonatomic, strong) NSMutableIndexSet *sectionIndexes;

- (instancetype)initWithSectionIndexes:(NSIndexSet *)sectionIndexes NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface AAPLLayoutRow ()
@property (nonatomic, readwrite, weak) AAPLLayoutSection *section;
@end

@interface AAPLLayoutSection ()
@property (nonatomic, strong) NSMutableArray *columnSeparatorLayoutAttributes;
@property (nonatomic, strong) NSMutableDictionary *sectionSeparatorLayoutAttributes;
@property (nonatomic, readonly) BOOL hasTopSectionSeparator;
@property (nonatomic, readonly) BOOL hasBottomSectionSeparator;
@end



@implementation AAPLLayoutSupplementaryItem
@synthesize frame = _frame;
@synthesize layoutAttributes = _layoutAttributes;
@synthesize itemIndex = _itemIndex;

- (id)copyWithZone:(NSZone *)zone
{
    AAPLLayoutSupplementaryItem *copy = [super copyWithZone:zone];
    // Probably should reset section after copy because otherwise it still points to the original section…
    copy.section = _section;
    copy.itemIndex = _itemIndex;
    copy.layoutAttributes = [_layoutAttributes copy];
    copy.frame = _frame;
    return copy;
}

- (NSIndexPath *)indexPath
{
    AAPLLayoutSection *sectionInfo = self.section;
    if (sectionInfo.globalSection)
        return [NSIndexPath indexPathWithIndex:self.itemIndex];
    else
        return [NSIndexPath indexPathForItem:self.itemIndex inSection:sectionInfo.sectionIndex];
}

- (AAPLCollectionViewLayoutAttributes *)layoutAttributes
{
    NSIndexPath *indexPath = self.indexPath;

    NSAssert(indexPath != nil, @"Shouldn't have nil indexPath");

    // Return the current layout attributes if we have some and the index path is the same.
    if (_layoutAttributes && [_layoutAttributes.indexPath isEqual:indexPath])
        return _layoutAttributes;

    AAPLLayoutSection *section = self.section;
    AAPLCollectionViewLayout *layout = section.layoutInfo.layout;
    AAPLCollectionViewLayoutAttributes *attributes = [AAPLCollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:self.elementKind withIndexPath:indexPath];

    attributes.frame = self.frame;
    attributes.unpinnedY = self.frame.origin.y;
    attributes.zIndex = HEADER_ZINDEX;
    attributes.pinnedHeader = NO;
    attributes.backgroundColor = self.backgroundColor ?: section.backgroundColor;
    attributes.selectedBackgroundColor = self.selectedBackgroundColor;
    attributes.layoutMargins = self.layoutMargins;
    attributes.editing = layout.editing;
    attributes.hidden = NO;
    attributes.shouldCalculateFittingSize = self.hasEstimatedHeight;
    attributes.theme = section.theme;
    attributes.simulatesSelection = self.simulatesSelection;
    attributes.pinnedSeparatorColor = self.pinnedSeparatorColor ?: section.separatorColor;
    attributes.pinnedBackgroundColor = self.pinnedBackgroundColor ?: section.backgroundColor;
    attributes.showsSeparator = self.showsSeparator;

    _layoutAttributes = attributes;
    return attributes;
}

- (void)setFrame:(CGRect)frame
{
    NSParameterAssert(!_layoutAttributes || frame.size.height != 0);
    _frame = frame;
    _layoutAttributes.frame = frame;
}

- (void)setFrame:(CGRect)frame invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    if (CGRectEqualToRect(frame, _frame))
        return;

    self.frame = frame;
    if (self.frame.size.height)
        [invalidationContext invalidateSupplementaryElementsOfKind:self.elementKind atIndexPaths:@[self.indexPath]];
}

@end


@implementation AAPLLayoutPlaceholder
@synthesize frame = _frame;
@synthesize layoutAttributes = _layoutAttributes;
@synthesize itemIndex = _itemIndex;

- (instancetype)initWithSectionIndexes:(NSIndexSet *)sectionIndexes
{
    self = [super init];
    if (!self)
        return nil;
    _sectionIndexes = [sectionIndexes mutableCopy];
    return self;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Don't call %@.", @(__PRETTY_FUNCTION__)];
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    AAPLLayoutPlaceholder *copy = [[[self class] alloc] initWithSectionIndexes:self.sectionIndexes];
    copy.itemIndex = _itemIndex;
    copy.height = _height;
    copy.hasEstimatedHeight = _hasEstimatedHeight;
    copy.layoutAttributes = [_layoutAttributes copy];
    copy.frame = _frame;
    copy.backgroundColor = _backgroundColor;

    return copy;
}

- (NSInteger)startingSectionIndex
{
    return (NSInteger)self.sectionIndexes.firstIndex;
}

- (NSInteger)endingSectionIndex
{
    return (NSInteger)self.sectionIndexes.lastIndex;
}

- (NSIndexPath *)indexPath
{
    return [NSIndexPath indexPathForItem:self.itemIndex inSection:self.startingSectionIndex];
}

- (AAPLCollectionViewLayoutAttributes *)layoutAttributes
{
    NSIndexPath *indexPath = self.indexPath;

    NSAssert(indexPath != nil, @"Shouldn't have nil indexPath");

    // Return the current layout attributes if we have some and the index path is the same.
    if (_layoutAttributes && [_layoutAttributes.indexPath isEqual:indexPath])
        return _layoutAttributes;

    AAPLCollectionViewLayoutAttributes *attributes = [AAPLCollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:AAPLCollectionElementKindPlaceholder withIndexPath:indexPath];

    attributes.frame = self.frame;
    attributes.unpinnedY = self.frame.origin.y;
    attributes.zIndex = HEADER_ZINDEX;
    attributes.pinnedHeader = NO;
    attributes.backgroundColor = self.backgroundColor;
    attributes.hidden = NO;
    attributes.shouldCalculateFittingSize = self.hasEstimatedHeight;

    _layoutAttributes = attributes;
    return attributes;
}

- (void)setFrame:(CGRect)frame
{
    NSParameterAssert(!_layoutAttributes || frame.size.height != 0);
    _frame = frame;
    _layoutAttributes.frame = frame;
}

- (void)setFrame:(CGRect)frame invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    if (CGRectEqualToRect(frame, _frame))
        return;

    self.frame = frame;
    if (self.frame.size.height)
        [invalidationContext invalidateSupplementaryElementsOfKind:AAPLCollectionElementKindPlaceholder atIndexPaths:@[self.indexPath]];
}

- (void)wasAddedToSection:(AAPLLayoutSection *)section
{
    [self.sectionIndexes addIndex:section.sectionIndex];
    NSAssert([self.sectionIndexes containsIndexesInRange:NSMakeRange(self.sectionIndexes.firstIndex, self.sectionIndexes.lastIndex - self.sectionIndexes.firstIndex + 1)], @"Section indexes for a placeholder must be contiguous");
}

@end

@implementation AAPLLayoutCell
@synthesize frame = _frame;
@synthesize layoutAttributes = _layoutAttributes;
@synthesize itemIndex = _itemIndex;

- (id)copyWithZone:(NSZone *)zone
{
    AAPLLayoutCell *copy = [[self class] new];
    // Need to reassign the row, because otherwise it will point to an incorrect one
    copy.row = _row;
    copy.itemIndex = _itemIndex;
    copy.dragging = _dragging;
    copy.columnIndex = _columnIndex;
    copy.hasEstimatedHeight = _hasEstimatedHeight;
    copy.layoutAttributes = [_layoutAttributes copy];
    copy.frame = _frame;
    return copy;
}

- (NSIndexPath *)indexPath
{
    AAPLLayoutSection *sectionInfo = self.row.section;
    if (sectionInfo.globalSection)
        return [NSIndexPath indexPathWithIndex:self.itemIndex];
    else
        return [NSIndexPath indexPathForItem:self.itemIndex inSection:sectionInfo.sectionIndex];
}

- (AAPLCollectionViewLayoutAttributes *)layoutAttributes
{
    NSIndexPath *indexPath = self.indexPath;

    // Return the current layout attributes if we have some and the index path is the same.
    if (_layoutAttributes && [_layoutAttributes.indexPath isEqual:indexPath])
        return _layoutAttributes;

    AAPLLayoutSection *section = self.row.section;
    AAPLCollectionViewLayout *layout = section.layoutInfo.layout;

    AAPLCollectionViewLayoutAttributes *attributes = [AAPLCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attributes.frame = self.frame;
    attributes.zIndex = DEFAULT_ZINDEX;
    attributes.backgroundColor = section.backgroundColor;
    attributes.selectedBackgroundColor = section.selectedBackgroundColor;
    attributes.columnIndex = self.columnIndex;
    attributes.editing = layout.editing ? [layout canEditItemAtIndexPath:indexPath] : NO;
    attributes.movable = layout.editing ? [layout canMoveItemAtIndexPath:indexPath] : NO;
    attributes.shouldCalculateFittingSize = self.hasEstimatedHeight;
    attributes.theme = section.theme;
    attributes.layoutMargins = section.layoutMargins;

    // Drag & Drop
    attributes.hidden = self.dragging;
    _layoutAttributes = attributes;
    return attributes;
}

- (void)setFrame:(CGRect)frame
{
    _frame = frame;
    _layoutAttributes.frame = frame;
}

- (void)setFrame:(CGRect)frame invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    if (CGRectEqualToRect(frame, _frame))
        return;
    self.frame = frame;
    [invalidationContext invalidateItemsAtIndexPaths:@[self.indexPath]];
}

- (void)setDragging:(BOOL)dragging
{
    if (dragging == _dragging)
        return;
    _dragging = dragging;
    _layoutAttributes.hidden = dragging;
}

@end


@implementation AAPLLayoutRow {
    NSMutableArray *_items;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _items = [NSMutableArray array];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    AAPLLayoutRow *copy = [[self class] new];

    copy.section = _section;
    copy.frame = _frame;

    copy->_items = [NSMutableArray array];
    for (AAPLLayoutCell *oldItem in _items)
        [copy addItem:[oldItem copy]];

    return copy;
}

- (void)addItem:(AAPLLayoutCell *)item
{
    [_items addObject:item];
    item.row = self;
}

- (void)setFrame:(CGRect)frame invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    if (CGRectEqualToRect(frame, _frame))
        return;

    // Setting the frame on a row needs to update the items within the row and the row separator
    AAPLCollectionViewLayoutAttributes *rowSeparatorLayoutAttributes = self.rowSeparatorLayoutAttributes;
    if (rowSeparatorLayoutAttributes) {
        CGRect separatorFrame = rowSeparatorLayoutAttributes.frame;
        separatorFrame.origin.y = CGRectGetMaxY(frame);
        rowSeparatorLayoutAttributes.frame = separatorFrame;
        AAPLInvalidateLayoutAttributes(invalidationContext, rowSeparatorLayoutAttributes);
    }

    for (AAPLLayoutCell *itemInfo in self.items) {
        CGRect itemFrame = itemInfo.frame;
        itemFrame.origin.y = frame.origin.y;
        [itemInfo setFrame:itemFrame invalidationContext:invalidationContext];
    }

    _frame = frame;
}

@end



@implementation AAPLLayoutSection

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _rows = [NSMutableArray array];
    _items = [NSMutableArray array];
    _phantomCellIndex = NSNotFound;
    _phantomCellSize = CGSizeZero;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    AAPLLayoutSection *copy = [super copyWithZone:zone];

    // Copy the rows first, then add the items from the copied rows. This should preserve the object graph of the copy.
    NSMutableArray *items = [NSMutableArray array];
    copy.rows = [NSMutableArray array];
    for (AAPLLayoutRow *oldRow in _rows) {
        AAPLLayoutRow *newRow = [oldRow copy];
        [copy addRow:newRow];
        [items addObjectsFromArray:newRow.items];
    }

    [items enumerateObjectsUsingBlock:^(AAPLLayoutCell *itemInfo, NSUInteger idx, BOOL *stop) {
        NSInteger itemIndex = (NSInteger)idx;
        itemInfo.itemIndex = itemIndex;
    }];

    copy.items = items;

    copy.headers = [NSMutableArray array];
    for (AAPLLayoutSupplementaryItem *supplementaryItem in _headers) {
        [copy addSupplementaryItem:[supplementaryItem copy]];
    }

    copy.footers = [NSMutableArray array];
    for (AAPLLayoutSupplementaryItem *supplementaryItem in _footers) {
        [copy addSupplementaryItem:[supplementaryItem copy]];
    }

    if (self.columnSeparatorLayoutAttributes) {
        copy.columnSeparatorLayoutAttributes = [NSMutableArray array];
        for (AAPLCollectionViewLayoutAttributes *layoutAttributes in self.columnSeparatorLayoutAttributes)
            [copy.columnSeparatorLayoutAttributes addObject:[layoutAttributes copy]];
    }

    if (self.sectionSeparatorLayoutAttributes) {
        NSMutableDictionary *newSeparators = copy.sectionSeparatorLayoutAttributes = [NSMutableDictionary dictionary];
        [self.sectionSeparatorLayoutAttributes enumerateKeysAndObjectsUsingBlock:^(NSNumber *itemIndex, AAPLCollectionViewLayoutAttributes *layoutAttributes, BOOL *stop) {
            newSeparators[itemIndex] = [layoutAttributes copy];
        }];
    }

    copy.backgroundAttribute = [_backgroundAttribute copy];

    copy.sectionIndex = _sectionIndex;
    copy.phantomCellIndex = _phantomCellIndex;
    copy.phantomCellSize = _phantomCellSize;

    copy.frame = _frame;

    return copy;
}

- (void)reset
{
    [_rows removeAllObjects];
    [_items removeAllObjects];
    _pinnableHeaders = nil;
    _nonPinnableHeaders = nil;
    _backgroundAttribute = nil;
    _headers = nil;
    _footers = nil;
    _columnSeparatorLayoutAttributes = nil;
}

- (BOOL)isGlobalSection
{
    return _sectionIndex == AAPLGlobalSectionIndex;
}

- (BOOL)shouldShowColumnSeparator
{
    return self.numberOfColumns > 1 && self.separatorColor && self.showsColumnSeparator && self.items.count > 0;
}

- (BOOL)hasBottomSectionSeparator
{
    return self.sectionSeparatorLayoutAttributes[@(SECTION_SEPARATOR_BOTTOM)] ? YES : NO;
}

- (BOOL)hasTopSectionSeparator
{
    return self.sectionSeparatorLayoutAttributes[@(SECTION_SEPARATOR_TOP)] ? YES : NO;
}

- (CGFloat)heightOfNonPinningHeaders
{
    __block BOOL valid = NO;

    __block CGFloat minY = CGFLOAT_MAX;
    __block CGFloat maxY = CGFLOAT_MIN;

    [self.nonPinnableHeaders enumerateObjectsUsingBlock:^(AAPLLayoutSupplementaryItem *supplementaryItem, NSUInteger itemIndex, BOOL *stop) {
        minY = MIN(minY, CGRectGetMinY(supplementaryItem.frame));
        maxY = MAX(maxY, CGRectGetMaxY(supplementaryItem.frame));
        valid = YES;
    }];

    if (valid)
        return maxY - minY;
    else
        return 0;
}

- (void)setPlaceholderInfo:(AAPLLayoutPlaceholder *)placeholderInfo
{
    if (placeholderInfo == _placeholderInfo)
        return;
    _placeholderInfo = placeholderInfo;
    [placeholderInfo wasAddedToSection:self];
}

- (AAPLCollectionViewLayoutAttributes *)backgroundAttribute
{
    if (_backgroundAttribute)
        return _backgroundAttribute;

    // only have background attribute on global section…
    if (!self.backgroundColor || _sectionIndex != AAPLGlobalSectionIndex)
        return nil;

    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndex:0];
    AAPLCollectionViewLayoutAttributes *backgroundAttribute = [AAPLCollectionViewLayoutAttributes layoutAttributesForDecorationViewOfKind:AAPLCollectionElementKindGlobalHeaderBackground withIndexPath:indexPath];
    // This will be updated by -filterSpecialAttributes
    backgroundAttribute.frame = self.frame;
    backgroundAttribute.unpinnedY = CGRectGetMinY(self.frame);
    backgroundAttribute.zIndex = DEFAULT_ZINDEX;
    backgroundAttribute.pinnedHeader = NO;
    backgroundAttribute.backgroundColor = self.backgroundColor;
    backgroundAttribute.hidden = NO;

    _backgroundAttribute = backgroundAttribute;
    return _backgroundAttribute;
}

- (void)addSupplementaryItem:(AAPLLayoutSupplementaryItem *)supplementaryInfo
{
    NSString *elementKind = supplementaryInfo.elementKind;
    if ([elementKind isEqualToString:UICollectionElementKindSectionHeader]) {
        if (!_headers)
            _headers = [NSMutableArray array];
        supplementaryInfo.itemIndex = _headers.count;
        [_headers addObject:supplementaryInfo];
    }
    else if ([elementKind isEqualToString:UICollectionElementKindSectionFooter]) {
        if (!_footers)
            _footers = [NSMutableArray array];
        supplementaryInfo.itemIndex = _footers.count;
        [_footers addObject:supplementaryInfo];
    }

    supplementaryInfo.section = self;
}

- (void)addRow:(AAPLLayoutRow *)rowInfo
{
    rowInfo.section = self;

    NSInteger rowIndex = self.rows.count;
    UIColor *separatorColor = self.separatorColor;

    static CGFloat hairline;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hairline = 1.0 / [[UIScreen mainScreen] scale];
    });

    // create the row separator if there isn't already one
    if (self.showsRowSeparator && !rowInfo.rowSeparatorLayoutAttributes) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:rowIndex inSection:self.sectionIndex];
        CGRect rowFrame = rowInfo.frame;
        CGFloat bottomY = CGRectGetMaxY(rowFrame);

        AAPLCollectionViewLayoutAttributes *separatorAttributes = [AAPLCollectionViewLayoutAttributes layoutAttributesForDecorationViewOfKind:AAPLCollectionElementKindRowSeparator withIndexPath:indexPath];
        separatorAttributes.frame = CGRectMake(self.separatorInsets.left, bottomY, rowFrame.size.width - self.separatorInsets.left - self.separatorInsets.right, hairline);
        separatorAttributes.backgroundColor = separatorColor;
        separatorAttributes.zIndex = SEPARATOR_ZINDEX;
        rowInfo.rowSeparatorLayoutAttributes = separatorAttributes;
        rowFrame.size.height += hairline;
        rowInfo.frame = rowFrame;
    }

    [self.rows addObject:rowInfo];
}

- (void)addItem:(AAPLLayoutCell *)item
{
    item.itemIndex = self.items.count;
    [self.items addObject:item];
}

- (CGFloat)columnWidth
{
    CGFloat width = self.layoutInfo.width;
    UIEdgeInsets margins = self.padding;
    NSInteger numberOfColumns = self.numberOfColumns;
    CGFloat columnWidth = (width - margins.left - margins.right) / numberOfColumns;
    return columnWidth;
}

- (void)updateColumnSeparatorsWithInvalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    if (!self.shouldShowColumnSeparator)
        return;

    static CGFloat hairline;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hairline = 1.0 / [[UIScreen mainScreen] scale];
    });

    CGFloat columnWidth = self.columnWidth;
    AAPLLayoutRow *firstRow = self.rows.firstObject;
    AAPLLayoutRow *lastRow = self.rows.lastObject;

    CGFloat top = CGRectGetMinY(firstRow.frame);
    CGFloat bottom = CGRectGetMaxY(lastRow.frame);
    NSInteger numberOfColumns = self.numberOfColumns;

    self.columnSeparatorLayoutAttributes = [NSMutableArray array];

    for (NSInteger columnIndex = 0; columnIndex < numberOfColumns; ++columnIndex) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:columnIndex inSection:self.sectionIndex];
        AAPLCollectionViewLayoutAttributes *separatorAttributes = [AAPLCollectionViewLayoutAttributes layoutAttributesForDecorationViewOfKind:AAPLCollectionElementKindColumnSeparator withIndexPath:indexPath];
        CGRect separatorFrame = CGRectMake(columnWidth * columnIndex, top, hairline, bottom - top);
        separatorAttributes.frame = separatorFrame;
        separatorAttributes.backgroundColor = self.separatorColor;
        separatorAttributes.zIndex = SEPARATOR_ZINDEX;

        [self.columnSeparatorLayoutAttributes addObject:separatorAttributes];

        [invalidationContext invalidateDecorationElementsOfKind:separatorAttributes.representedElementKind atIndexPaths:@[separatorAttributes.indexPath]];
    }
}

/// Create any additional layout attributes, this requires knowing what sections actually have any content.
- (void)finalizeLayoutAttributesForSectionsWithContent:(NSIndexSet *)sectionsWithContent
{
    CGRect frame = self.frame;
    CGFloat width = CGRectGetWidth(frame);
    NSInteger sectionIndex = self.sectionIndex;

    static CGFloat hairline;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hairline = 1.0 / [[UIScreen mainScreen] scale];
    });

    BOOL showSectionSeparators = self.showsSectionSeparator && self.items.count > 0;

    // Hide the row separator for the last row in the section.
    if (self.showsRowSeparator) {
        AAPLLayoutRow *rowInfo = self.rows.lastObject;
        rowInfo.rowSeparatorLayoutAttributes.hidden = YES;
    }

    if (showSectionSeparators) {
        self.sectionSeparatorLayoutAttributes = [NSMutableDictionary dictionary];

        AAPLLayoutInfo *layoutInfo = self.layoutInfo;

        NSInteger previousSectionIndexWithContent = [sectionsWithContent indexLessThanIndex:self.sectionIndex];
        AAPLLayoutSection *previousSectionWithContent = (NSNotFound != previousSectionIndexWithContent ? [layoutInfo sectionAtIndex:previousSectionIndexWithContent] : nil);

        // Only need to show the top separator when there is a section with content before this one, but it doesn't have a bottom separator already
        if (previousSectionWithContent && !previousSectionWithContent.hasBottomSectionSeparator) {
            // Create top section separator
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:SECTION_SEPARATOR_TOP inSection:sectionIndex];
            AAPLCollectionViewLayoutAttributes *separatorAttributes = [AAPLCollectionViewLayoutAttributes layoutAttributesForDecorationViewOfKind:AAPLCollectionElementKindSectionSeparator withIndexPath:indexPath];

            separatorAttributes.frame = CGRectMake(self.sectionSeparatorInsets.left, self.frame.origin.y, width - self.sectionSeparatorInsets.left - self.sectionSeparatorInsets.right, hairline);
            separatorAttributes.backgroundColor = self.sectionSeparatorColor;
            separatorAttributes.zIndex = SECTION_SEPARATOR_ZINDEX;

            self.sectionSeparatorLayoutAttributes[@(SECTION_SEPARATOR_TOP)] = separatorAttributes;
        }

        NSInteger nextSectionIndexWithContent = [sectionsWithContent indexGreaterThanIndex:self.sectionIndex];
        AAPLLayoutSection *nextSectionWithContent = (NSNotFound != nextSectionIndexWithContent ? [layoutInfo sectionAtIndex:nextSectionIndexWithContent] : nil);

        // Only need to show the bottom separator when there is another section with content after this one that doesn't have a top separator OR we've been explicitly told to show the section separator when this is the last section
        if ((nextSectionWithContent && !nextSectionWithContent.hasTopSectionSeparator) || (!nextSectionWithContent && self.showsSectionSeparatorWhenLastSection)) {
            // Create bottom section separator
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:SECTION_SEPARATOR_BOTTOM inSection:sectionIndex];
            AAPLCollectionViewLayoutAttributes *separatorAttributes = [AAPLCollectionViewLayoutAttributes layoutAttributesForDecorationViewOfKind:AAPLCollectionElementKindSectionSeparator withIndexPath:indexPath];

            separatorAttributes.frame = CGRectMake(self.sectionSeparatorInsets.left, CGRectGetMaxY(self.frame), width - self.sectionSeparatorInsets.left - self.sectionSeparatorInsets.right, hairline);
            separatorAttributes.backgroundColor = self.sectionSeparatorColor;
            separatorAttributes.zIndex = SECTION_SEPARATOR_ZINDEX;

            self.sectionSeparatorLayoutAttributes[@(SECTION_SEPARATOR_BOTTOM)] = separatorAttributes;
        }
    }

    [self updateColumnSeparatorsWithInvalidationContext:nil];
}

- (void)enumerateLayoutAttributesWithBlock:(void (^)(AAPLCollectionViewLayoutAttributes *, BOOL *))block
{
    NSParameterAssert(block != nil);
    BOOL stop= NO;
    NSInteger numberOfItems = self.items.count;
    BOOL globalSection = self.globalSection;

    if (_backgroundAttribute) {
        block(_backgroundAttribute, &stop);
        if (stop)
            return;
    }

    for (NSNumber *key in self.sectionSeparatorLayoutAttributes) {
        AAPLCollectionViewLayoutAttributes *layoutAttributes = self.sectionSeparatorLayoutAttributes[key];
        block(layoutAttributes, &stop);
        if (stop)
            return;
    }

    for (AAPLCollectionViewLayoutAttributes *layoutAttributes in self.columnSeparatorLayoutAttributes) {
        block(layoutAttributes, &stop);
        if (stop)
            return;
    }

    for (AAPLLayoutSupplementaryItem *supplementaryItem in self.headers) {
        // Don't enumerate hidden or 0 height supplementary items
        if (supplementaryItem.hidden || !supplementaryItem.height)
            continue;

        // For non-global sections, don't enumerate if there are no items and not marked as visible when showing placeholder
        if (!globalSection && !numberOfItems && !supplementaryItem.visibleWhileShowingPlaceholder)
            continue;

        block(supplementaryItem.layoutAttributes, &stop);
        if (stop)
            return;
    }

    AAPLLayoutPlaceholder *placeholderInfo = self.placeholderInfo;
    if (placeholderInfo && placeholderInfo.startingSectionIndex == self.sectionIndex) {
        block(placeholderInfo.layoutAttributes, &stop);
        if (stop)
            return;
    }

    for (AAPLLayoutRow *rowInfo in self.rows) {
        if (rowInfo.rowSeparatorLayoutAttributes) {
            block(rowInfo.rowSeparatorLayoutAttributes, &stop);
            if (stop)
                return;
        }

        for (AAPLLayoutCell *itemInfo in rowInfo.items) {
            block(itemInfo.layoutAttributes, &stop);
            if (stop)
                return;
        }
    }

    for (AAPLLayoutSupplementaryItem *supplementaryItem in self.footers) {
        // Don't enumerate hidden or 0 height supplementary items
        if (supplementaryItem.hidden || !supplementaryItem.height)
            continue;
        // For non-global sections, don't enumerate if there are no items and not marked as visible when showing placeholder
        if (!globalSection && !numberOfItems && !supplementaryItem.visibleWhileShowingPlaceholder)
            continue;
        block(supplementaryItem.layoutAttributes, &stop);
        if (stop)
            return;
    }
}

- (void)enumerateSupplementaryItemsOfKind:(NSString *)kind pinnable:(BOOL)pinnable block:(void(^)(AAPLLayoutSupplementaryItem *supplementaryItem, BOOL *stop))block
{
    NSAssert([kind isEqualToString:UICollectionElementKindSectionFooter] || [kind isEqualToString:UICollectionElementKindSectionHeader], @"The kind parameter must be either UICollectionElementKindSectionFooter or UICollectionElementKindSectionHeader");

    NSArray *group = ([kind isEqualToString:UICollectionElementKindSectionHeader] ? self.headers : self.footers);
    BOOL stop = NO;
    NSInteger numberOfItems = self.items.count;
    BOOL globalSection = self.globalSection;

    for (AAPLLayoutSupplementaryItem *supplementaryItem in group) {
        // Don't enumerate hidden or 0 height supplementary items
        if (supplementaryItem.hidden || !supplementaryItem.height)
            continue;

        // For non-global sections, don't enumerate if there are no items and not marked as visible when showing placeholder
        if (!globalSection && !numberOfItems && !supplementaryItem.visibleWhileShowingPlaceholder)
            continue;

        // Skip those that don't match the pinnable parameter
        if (supplementaryItem.shouldPin != pinnable)
            continue;

        block(supplementaryItem, &stop);
        if (stop)
            return;
    }
}

- (void)setFrame:(CGRect)frame invalidationContext:(UICollectionViewFlowLayoutInvalidationContext *)invalidationContext
{
    if (CGRectEqualToRect(frame, _frame))
        return;

    CGFloat deltaY = frame.origin.y - _frame.origin.y;

    for (AAPLLayoutSupplementaryItem *supplementaryItem in self.headers) {
        CGRect supplementaryFrame = CGRectOffset(supplementaryItem.frame, 0, deltaY);
        [supplementaryItem setFrame:supplementaryFrame invalidationContext:invalidationContext];
    }

    for (AAPLLayoutRow *rowInfo in self.rows) {
        CGRect rowFrame = CGRectOffset(rowInfo.frame, 0, deltaY);
        [rowInfo setFrame:rowFrame invalidationContext:invalidationContext];
    }

    if (_backgroundAttribute) {
        CGRect backgroundRect = CGRectOffset(_backgroundAttribute.frame, 0, deltaY);
        _backgroundAttribute.frame = backgroundRect;
        [invalidationContext invalidateDecorationElementsOfKind:_backgroundAttribute.representedElementKind atIndexPaths:@[_backgroundAttribute.indexPath]];
    }

    for (AAPLLayoutSupplementaryItem *supplementaryItem in self.footers) {
        CGRect supplementaryFrame = CGRectOffset(supplementaryItem.frame, 0, deltaY);
        [supplementaryItem setFrame:supplementaryFrame invalidationContext:invalidationContext];
    }

    for (AAPLCollectionViewLayoutAttributes *layoutAttributes in self.columnSeparatorLayoutAttributes) {
        layoutAttributes.frame = CGRectOffset(layoutAttributes.frame, 0, deltaY);
        [invalidationContext invalidateDecorationElementsOfKind:layoutAttributes.representedElementKind atIndexPaths:@[layoutAttributes.indexPath]];
    }

    for (NSNumber *key in self.sectionSeparatorLayoutAttributes) {
        AAPLCollectionViewLayoutAttributes *layoutAttributes = self.sectionSeparatorLayoutAttributes[key];
        layoutAttributes.frame = CGRectOffset(layoutAttributes.frame, 0, deltaY);
        [invalidationContext invalidateDecorationElementsOfKind:layoutAttributes.representedElementKind atIndexPaths:@[layoutAttributes.indexPath]];
    }

    self.frame = frame;
}

/// Offset the contents of this section that are after the specified position the given distance
- (void)offsetContentAfterPosition:(CGFloat)originY distance:(CGFloat)deltaY invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    for (AAPLLayoutSupplementaryItem *supplementaryItem in self.headers) {
        CGRect supplementaryFrame = supplementaryItem.frame;
        if (CGRectGetMinY(supplementaryFrame) < originY)
            continue;
        [supplementaryItem setFrame:CGRectOffset(supplementaryFrame, 0, deltaY) invalidationContext:invalidationContext];
    }

    for (AAPLLayoutSupplementaryItem *supplementaryItem in self.footers) {
        CGRect supplementaryFrame = supplementaryItem.frame;
        if (CGRectGetMinY(supplementaryFrame) < originY)
            continue;
        [supplementaryItem setFrame:CGRectOffset(supplementaryFrame, 0, deltaY) invalidationContext:invalidationContext];
    }

    for (AAPLCollectionViewLayoutAttributes *layoutAttributes in self.columnSeparatorLayoutAttributes) {
        CGRect separatorFrame = layoutAttributes.frame;
        if (CGRectGetMinY(separatorFrame) < originY)
            continue;
        layoutAttributes.frame = CGRectOffset(separatorFrame, 0, deltaY);
        [invalidationContext invalidateDecorationElementsOfKind:layoutAttributes.representedElementKind atIndexPaths:@[layoutAttributes.indexPath]];
    }

    for (NSNumber *key in self.sectionSeparatorLayoutAttributes) {
        AAPLCollectionViewLayoutAttributes *layoutAttributes = self.sectionSeparatorLayoutAttributes[key];
        CGRect separatorFrame = layoutAttributes.frame;
        if (CGRectGetMinY(separatorFrame) < originY)
            continue;
        layoutAttributes.frame = CGRectOffset(separatorFrame, 0, deltaY);
        [invalidationContext invalidateDecorationElementsOfKind:layoutAttributes.representedElementKind atIndexPaths:@[layoutAttributes.indexPath]];
    }

    for (AAPLLayoutRow *rowInfo in self.rows) {
        CGRect rowFrame = rowInfo.frame;
        if (CGRectGetMinY(rowFrame) < originY)
            continue;
        [rowInfo setFrame:CGRectOffset(rowFrame, 0, deltaY) invalidationContext:invalidationContext];
    }

}

- (CGFloat)setSize:(CGSize)size forItemAtIndex:(NSInteger)index invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    AAPLLayoutCell *itemInfo = self.items[index];
    AAPLLayoutRow *rowInfo = itemInfo.row;

    if (CGSizeEqualToSize(size, itemInfo.frame.size))
        return 0;

    // Items in a row are always the same height…
    CGRect itemFrame = itemInfo.frame;
    CGRect rowFrame = rowInfo.frame;

    itemFrame.size = size;
    [itemInfo setFrame:itemFrame invalidationContext:invalidationContext];

    CGFloat originalRowHeight = CGRectGetHeight(rowFrame);
    CGFloat newRowHeight = 0;

    // calculate the max row height based on the current collection of items…
    for (AAPLLayoutCell *rowItemInfo in rowInfo.items) {
        newRowHeight = MAX(newRowHeight, CGRectGetHeight(rowItemInfo.frame));
    }

    // If the height of the row hasn't changed, then nothing else needs to move
    if (newRowHeight == originalRowHeight)
        return 0;

    CGFloat offsetPositionY = CGRectGetMaxY(rowFrame);
    CGFloat deltaH = newRowHeight - originalRowHeight;

    rowFrame.size.height += deltaH;
    rowInfo.frame = rowFrame;

    [self offsetContentAfterPosition:offsetPositionY distance:deltaH invalidationContext:invalidationContext];
    [self updateColumnSeparatorsWithInvalidationContext:invalidationContext];

    return deltaH;
}

- (CGFloat)setSize:(CGSize)size forHeaderAtIndex:(NSInteger)index invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    AAPLLayoutSupplementaryItem *headerInfo = self.headers[index];

    NSAssert(headerInfo != nil, @"Should always be able to find the header info for a given attributes index path.");

    CGRect frame = headerInfo.frame;
    CGFloat afterY = CGRectGetMaxY(frame);

    CGFloat deltaH = size.height - CGRectGetHeight(frame);
    frame.size = size;
    [headerInfo setFrame:frame invalidationContext:invalidationContext];

    if (0 == deltaH)
        return 0;

    [self offsetContentAfterPosition:afterY distance:deltaH invalidationContext:invalidationContext];
    return deltaH;
}

- (CGFloat)setSize:(CGSize)size forFooterAtIndex:(NSInteger)index invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    AAPLLayoutSupplementaryItem *footerInfo = self.footers[index];

    NSAssert(footerInfo != nil, @"Should always be able to find the footer info for a given attributes index path.");

    CGRect frame = footerInfo.frame;
    CGFloat afterY = CGRectGetMaxY(frame);

    CGFloat deltaH = size.height - CGRectGetHeight(frame);
    frame.size = size;
    [footerInfo setFrame:frame invalidationContext:invalidationContext];

    if (0 == deltaH)
        return 0;

    [self offsetContentAfterPosition:afterY distance:deltaH invalidationContext:invalidationContext];
    return deltaH;
}

- (CGFloat)layoutWithOrigin:(CGFloat)start invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    AAPLLayoutInfo *layoutInfo = self.layoutInfo;

#if !SUPPORTS_SELFSIZING
    AAPLCollectionViewLayout *layout = layoutInfo.layout;
#endif

    const CGFloat width = layoutInfo.width;
    const UIEdgeInsets margins = self.padding;
    const NSInteger numberOfItems = self.items.count;
    const NSInteger numberOfColumns = self.numberOfColumns;
    const CGFloat columnWidth = self.columnWidth;
    __block CGFloat rowHeight = 0;

    __block CGFloat originX = margins.left;
    __block CGFloat originY = start;

    __block NSMutableArray *pinnableHeaders = [NSMutableArray array];
    __block NSMutableArray *nonPinnableHeaders = self.globalSection ? [NSMutableArray array] : nil;

    void (^layoutSupplementaryView)(AAPLLayoutSupplementaryItem *supplementaryItem, NSUInteger itemIndex, BOOL *stop) = ^(AAPLLayoutSupplementaryItem *supplementaryItem, NSUInteger itemIndex, BOOL *stop) {
        // skip supplementary item if there are no items and it isn't visible while showing the placeholder
        if (!numberOfItems && !supplementaryItem.visibleWhileShowingPlaceholder)
            return;

        CGFloat height = supplementaryItem.fixedHeight;

        // skip supplementary items that are hidden
        if (supplementaryItem.hidden || !height)
            return;

        supplementaryItem.frame = CGRectMake(0, originY, width, height);

#if !SUPPORTS_SELFSIZING
        if (supplementaryItem.hasEstimatedHeight) {
            CGSize measuredSize = [layout measuredSizeForSupplementaryItem:supplementaryItem];
            height = supplementaryItem.height = measuredSize.height;
            supplementaryItem.frame = CGRectMake(0, originY, width, height);
        }
#endif

        originY += height;

        if ([supplementaryItem.elementKind isEqualToString:UICollectionElementKindSectionHeader]) {
            if (supplementaryItem.shouldPin)
                [pinnableHeaders addObject:supplementaryItem];
            else if (nonPinnableHeaders)
                [nonPinnableHeaders addObject:supplementaryItem];
        }

        [invalidationContext invalidateSupplementaryElementsOfKind:supplementaryItem.elementKind atIndexPaths:@[supplementaryItem.indexPath]];
    };

    // Lay out headers
    [self.headers enumerateObjectsUsingBlock:layoutSupplementaryView];
    _pinnableHeaders = pinnableHeaders;
    _nonPinnableHeaders = nonPinnableHeaders;

    // Next lay out all the items in rows
    [self.rows removeAllObjects];

    AAPLLayoutPlaceholder *placeholderInfo = self.placeholderInfo;
    if (placeholderInfo && placeholderInfo.startingSectionIndex == self.sectionIndex) {
        placeholderInfo.frame = CGRectMake(0, originY, width, placeholderInfo.height);

#if !SUPPORTS_SELFSIZING
        if (placeholderInfo.hasEstimatedHeight) {
            CGSize measuredSize = [layout measuredSizeForPlaceholder:placeholderInfo];
            // We'll add in the shared height in -finalizeLayout
            placeholderInfo.height = measuredSize.height;
            placeholderInfo.frame = CGRectMake(0, originY, width, placeholderInfo.height);
            placeholderInfo.hasEstimatedHeight = NO;
        }
#endif

        originY += placeholderInfo.height;
    }

    // Lay out items and footers only if there actually ARE items and there's not a placeholder associated with this section.
    if (!placeholderInfo && numberOfItems) {

        originY += margins.top;

        __block NSInteger columnIndex = 0;
        __block AAPLLayoutRow *row = [AAPLLayoutRow new];
        __block CGFloat height;

        NSInteger phantomCellIndex = self.phantomCellIndex;

        // Make certain the first row has a back pointer to this section
        row.section = self;

        // Advance to the next column and if necessary the next row. Takes into account the phantom cell index.
        void (^nextColumn)() = ^{
            if (rowHeight < height)
                rowHeight = height;

            switch (self.cellLayoutOrder) {
                case AAPLCellLayoutOrderLeftToRight:
                    originX += columnWidth;
                    break;
                case AAPLCellLayoutOrderRightToLeft:
                    originX -= columnWidth;
                    break;
            }

            ++columnIndex;

            // keep row height up to date
            CGRect rowFrame = row.frame;
            rowFrame.size.height = rowHeight;
            row.frame = rowFrame;

            if (!(columnIndex % numberOfColumns)) {
                originY += rowHeight;
                rowHeight = 0;
                columnIndex = 0;

                switch (self.cellLayoutOrder) {
                    case AAPLCellLayoutOrderLeftToRight:
                        originX = margins.left;
                        break;
                    case AAPLCellLayoutOrderRightToLeft:
                        originX = width - margins.right - columnWidth;
                        break;
                }

                // only create a new row if there were items in the previous row.
                if (row.items.count) {
                    // Add the previous row, before creating a new one
                    [self addRow:row];
                    // Update the origin based on the actual frame of the row…
                    originY = CGRectGetMaxY(row.frame);

                    row = [AAPLLayoutRow new];
                    // A row always needs a back pointer to the section…
                    row.section = self;
                }
                row.frame = CGRectMake(margins.left, originY, width, rowHeight);
            }
        };

        // set up the initial row frame
        row.frame = CGRectMake(margins.left, originY, width, rowHeight);

        [self.items enumerateObjectsUsingBlock:^(AAPLLayoutCell *item, NSUInteger itemIndex, BOOL *stop) {
            BOOL phantomCell = ((NSInteger)itemIndex == phantomCellIndex);
            BOOL hiddenCell = item.dragging;

            if (phantomCell) {
                height = self.phantomCellSize.height;
                nextColumn();
            }

            height = CGRectGetHeight(item.frame);

            if (hiddenCell) {
                item.frame = CGRectMake(originX, originY, columnWidth, height);
                item.columnIndex = NSNotFound;
                [row addItem:item];
                return;
            }

            item.frame = CGRectMake(originX, originY, columnWidth, height);
            item.columnIndex = columnIndex;
            [row addItem:item];

#if !SUPPORTS_SELFSIZING
            if (item.hasEstimatedHeight) {
                CGSize measuredSize = [layout measuredSizeForCell:item];
                item.frame = CGRectMake(originX, originY, columnWidth, measuredSize.height);
                item.hasEstimatedHeight = NO;
                height = measuredSize.height;
            }
#endif

            [invalidationContext invalidateItemsAtIndexPaths:@[item.indexPath]];
            nextColumn();
        }];

        if (row.items.count)
            [self addRow:row];

        originY += rowHeight + margins.bottom;
    }

    // lay out all footers
    [self.footers enumerateObjectsUsingBlock:layoutSupplementaryView];

    self.frame = CGRectMake(0, start, width, originY - start);
    return originY;
}

#pragma mark AAPLLayoutAttributesLookup

- (AAPLCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryItemOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    NSInteger itemIndex = indexPath.length > 1 ? indexPath.item : [indexPath indexAtPosition:0];

    if ([kind isEqualToString:AAPLCollectionElementKindPlaceholder])
        return self.placeholderInfo.layoutAttributes;

    AAPLLayoutSupplementaryItem *supplementaryItem;

    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        if (itemIndex >= (NSInteger)self.headers.count)
            return nil;
        supplementaryItem = self.headers[itemIndex];
    }
    else if ([kind isEqualToString:UICollectionElementKindSectionFooter]) {
        if (itemIndex >= (NSInteger)self.footers.count)
            return nil;
        supplementaryItem = self.footers[itemIndex];
    }

    // There's no layout attributes if this section isn't the global section, there are no items and the supplementary item shouldn't be shown when the placeholder is visible (e.g. no items).
    if (!self.globalSection && !self.items.count && !supplementaryItem.visibleWhileShowingPlaceholder)
        return nil;

    return supplementaryItem.layoutAttributes;
}

- (AAPLCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    NSInteger itemIndex = indexPath.length > 1 ? indexPath.item : [indexPath indexAtPosition:0];

    if ([kind isEqualToString:AAPLCollectionElementKindGlobalHeaderBackground])
        return self.backgroundAttribute;

    if ([kind isEqualToString:AAPLCollectionElementKindColumnSeparator]) {
        if (itemIndex >= (NSInteger)self.columnSeparatorLayoutAttributes.count)
            return nil;
        return self.columnSeparatorLayoutAttributes[itemIndex];
    }

    if ([kind isEqualToString:AAPLCollectionElementKindSectionSeparator]) {
        return self.sectionSeparatorLayoutAttributes[@(itemIndex)];
    }

    if ([kind isEqualToString:AAPLCollectionElementKindRowSeparator]) {
        if (itemIndex >= (NSInteger)self.rows.count)
            return nil;
        AAPLLayoutRow *rowInfo = self.rows[itemIndex];
        return rowInfo.rowSeparatorLayoutAttributes;
    }

    return nil;
}

- (AAPLCollectionViewLayoutAttributes *)layoutAttributesForCellAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger itemIndex = indexPath.length > 1 ? indexPath.item : [indexPath indexAtPosition:0];
    if (self.placeholderInfo || itemIndex >= (NSInteger)_items.count)
        return nil;
    AAPLLayoutCell *itemInfo = self.items[itemIndex];
    return itemInfo.layoutAttributes;
}

@end



@implementation AAPLLayoutInfo

- (instancetype)initWithLayout:(AAPLCollectionViewLayout *__weak)layout
{
    self = [super init];
    if (!self)
        return nil;
    _sections = [NSMutableArray array];
    _numberOfPlaceholders = 0;
    _layout = layout;
    return self;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Don't call %@.", @(__PRETTY_FUNCTION__)];
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    AAPLLayoutInfo *copy = [[self class] new];
    copy.width = self.width;
    copy.height = self.height;
    copy.layout = self.layout;
    copy.contentOffsetY = self.contentOffsetY;
    copy.numberOfPlaceholders = self.numberOfPlaceholders;

    AAPLLayoutSection *globalSectionCopy = [self.globalSection copy];
    globalSectionCopy.layoutInfo = copy;
    copy.globalSection = globalSectionCopy;

    NSMutableArray *newSections = copy.sections = [NSMutableArray array];
    [self.sections enumerateObjectsUsingBlock:^(AAPLLayoutSection *sectionInfo, NSUInteger idx, BOOL *stop) {
        AAPLLayoutSection *sectionCopy = [sectionInfo copy];
        sectionCopy.layoutInfo = copy;
        [newSections addObject:sectionCopy];
    }];
    return copy;
}

- (AAPLLayoutSection *)newSectionWithIndex:(NSInteger)sectionIndex
{
    AAPLLayoutSection *section = [[AAPLLayoutSection alloc] init];
    section.layoutInfo = self;
    section.sectionIndex = sectionIndex;
    if (sectionIndex == AAPLGlobalSectionIndex)
        self.globalSection = section;
    else {
        NSAssert(sectionIndex == (NSInteger)self.sections.count, @"Number of sections out of sync with the section index");
        [self.sections addObject:section];
    }
    return section;
}

- (AAPLLayoutPlaceholder *)newPlaceholderStartingAtSectionIndex:(NSInteger)sectionIndex
{
    AAPLLayoutPlaceholder *placeholder = [[AAPLLayoutPlaceholder alloc] initWithSectionIndexes:[NSIndexSet indexSetWithIndex:sectionIndex]];
    self.numberOfPlaceholders++;
    return placeholder;
}

- (NSInteger)numberOfSections
{
    return (NSInteger)_sections.count;
}

- (BOOL)hasGlobalSection
{
    return _globalSection ? YES : NO;
}

- (AAPLLayoutSection *)sectionAtIndex:(NSInteger)sectionIndex
{
    if (AAPLGlobalSectionIndex == sectionIndex)
        return _globalSection;

    if (sectionIndex < 0 || sectionIndex >= (NSInteger)_sections.count)
        return nil;
    return _sections[sectionIndex];
}

- (void)enumerateSectionsWithBlock:(void(^)(NSInteger sectionIndex, AAPLLayoutSection *sectionInfo, BOOL *stop))block
{
    NSParameterAssert(block != nil);

    if (_globalSection) {
        BOOL stop = NO;
        block(AAPLGlobalSectionIndex, _globalSection, &stop);
        if (stop)
            return;
    }

    [_sections enumerateObjectsUsingBlock:^(AAPLLayoutSection *sectionInfo, NSUInteger sectionIndex, BOOL *stop) {
        block((NSInteger)sectionIndex, sectionInfo, stop);
    }];
}

- (void)invalidate
{
    self.globalSection = nil;
    [self.sections removeAllObjects];
}

- (void)finalizeLayout
{
    NSMutableIndexSet *sectionsWithContent = [NSMutableIndexSet indexSet];

    [self.sections enumerateObjectsUsingBlock:^(AAPLLayoutSection *sectionInfo, NSUInteger sectionIndex, BOOL *stop) {
        if (sectionInfo.globalSection)
            return;

        AAPLLayoutPlaceholder *placeholderInfo = sectionInfo.placeholderInfo;

        // If there's a placeholder and it didn't start here or end here, there's no content to worry about, because we're not going to show the items or any headers or footers.
        if (placeholderInfo && placeholderInfo.startingSectionIndex != sectionInfo.sectionIndex && placeholderInfo.endingSectionIndex != sectionInfo.sectionIndex) {
            return;
        }

#if !SUPPORTS_SELFSIZING
        if (placeholderInfo && placeholderInfo.startingSectionIndex == sectionInfo.sectionIndex) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:sectionInfo.sectionIndex];
            [self setSize:placeholderInfo.frame.size forElementOfKind:AAPLCollectionElementKindPlaceholder atIndexPath:indexPath invalidationContext:nil];
        }
#endif

        if (sectionInfo.items.count) {
            [sectionsWithContent addIndex:sectionInfo.sectionIndex];
            return;
        }

        // There are no items, need to determine if there are any headers or footers that will be displayed
        for (AAPLLayoutSupplementaryItem *supplementaryItem in sectionInfo.headers) {
            if (!supplementaryItem.visibleWhileShowingPlaceholder || supplementaryItem.hidden || !supplementaryItem.height)
                continue;
            [sectionsWithContent addIndex:sectionInfo.sectionIndex];
            return;
        }

        for (AAPLLayoutSupplementaryItem *supplementaryItem in sectionInfo.footers) {
            if (!supplementaryItem.visibleWhileShowingPlaceholder || supplementaryItem.hidden || !supplementaryItem.height)
                continue;
            [sectionsWithContent addIndex:sectionInfo.sectionIndex];
            return;
        }
    }];

    // Now go back through all the sections and ask them to finalise their layout
    [self.sections enumerateObjectsUsingBlock:^(AAPLLayoutSection *sectionInfo, NSUInteger sectionIndex, BOOL *stop) {
        [sectionInfo finalizeLayoutAttributesForSectionsWithContent:sectionsWithContent];
    }];
}

- (void)offsetSectionsByDistance:(CGFloat)deltaY afterSectionAtIndex:(NSInteger)sectionIndex invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    NSInteger numberOfSections = (NSInteger)self.sections.count;

    if (sectionIndex == AAPLGlobalSectionIndex)
        sectionIndex = 0;
    else
        sectionIndex = sectionIndex + 1;

    for (; sectionIndex < numberOfSections; ++sectionIndex) {
        AAPLLayoutSection *sectionInfo = self.sections[sectionIndex];
        CGRect sectionFrame = CGRectOffset(sectionInfo.frame, 0, deltaY);
        [sectionInfo setFrame:sectionFrame invalidationContext:invalidationContext];

        // Move placeholder that happens to start at this section index
        AAPLLayoutPlaceholder *placeholderInfo = sectionInfo.placeholderInfo;
        if (placeholderInfo && placeholderInfo.startingSectionIndex == sectionIndex) {
            CGRect placeholderFrame = CGRectOffset(placeholderInfo.frame, 0, deltaY);
            [placeholderInfo setFrame:placeholderFrame invalidationContext:invalidationContext];
        }
    }
}

- (void)setSize:(CGSize)size forItemAtIndexPath:(NSIndexPath *)indexPath invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    NSUInteger sectionIndex = indexPath.section;

    AAPLLayoutSection *sectionInfo = self.sections[sectionIndex];
    CGFloat deltaY = [sectionInfo setSize:size forItemAtIndex:indexPath.item invalidationContext:invalidationContext];
    [self offsetSectionsByDistance:deltaY afterSectionAtIndex:sectionIndex invalidationContext:invalidationContext];
    invalidationContext.contentSizeAdjustment = CGSizeMake(0, deltaY);
}

- (CGFloat)setSize:(CGSize)size forPlaceholderAtSectionIndex:(NSUInteger)sectionIndex invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    AAPLLayoutSection *sectionInfo = [self sectionAtIndex:sectionIndex];
    AAPLLayoutPlaceholder *placeholderInfo = sectionInfo.placeholderInfo;
    CGRect frame = placeholderInfo.frame;

    CGFloat sharedHeight = (self.heightAvailableForPlaceholders / self.numberOfPlaceholders);
    CGFloat deltaY = size.height - frame.size.height;

    if (sharedHeight > 0)
        deltaY = (size.height + sharedHeight) - frame.size.height;

    frame.size.height += deltaY;

    if (deltaY > 0)
        [placeholderInfo setFrame:frame invalidationContext:invalidationContext];
    return deltaY;
}

- (void)setSize:(CGSize)size forElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    NSUInteger sectionIndex = (indexPath.length == 1 ? AAPLGlobalSectionIndex : indexPath.section);
    NSUInteger itemIndex = (indexPath.length == 1 ? [indexPath indexAtPosition:0] : indexPath.item);

    AAPLLayoutSection *sectionInfo = [self sectionAtIndex:sectionIndex];
    CGFloat deltaY = 0;
    if ([kind isEqualToString:UICollectionElementKindSectionHeader])
        deltaY = [sectionInfo setSize:size forHeaderAtIndex:itemIndex invalidationContext:invalidationContext];
    else if ([kind isEqualToString:UICollectionElementKindSectionFooter])
        deltaY = [sectionInfo setSize:size forFooterAtIndex:itemIndex invalidationContext:invalidationContext];
    else if ([kind isEqualToString:AAPLCollectionElementKindPlaceholder])
        deltaY = [self setSize:size forPlaceholderAtSectionIndex:sectionIndex invalidationContext:invalidationContext];

    [self offsetSectionsByDistance:deltaY afterSectionAtIndex:sectionIndex invalidationContext:invalidationContext];
    invalidationContext.contentSizeAdjustment = CGSizeMake(0, deltaY);
}

- (void)invalidateMetricsForItemAtIndexPath:(NSIndexPath *)indexPath invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    UICollectionViewCell *cell = [self.layout.collectionView cellForItemAtIndexPath:indexPath];
    if (!cell)
        return;

    AAPLCollectionViewLayoutAttributes *attributes = [self layoutAttributesForCellAtIndexPath:indexPath];
    attributes = [attributes copy];
    attributes.shouldCalculateFittingSize = YES;

    UICollectionViewLayoutAttributes *newAttributes = [cell preferredLayoutAttributesFittingAttributes:attributes];
    if (CGSizeEqualToSize(newAttributes.frame.size, attributes.frame.size))
        return;

    [self setSize:newAttributes.frame.size forItemAtIndexPath:indexPath invalidationContext:invalidationContext];
}

- (void)invalidateMetricsForElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext
{
    UICollectionReusableView *view = [self.layout.collectionView aapl_supplementaryViewOfKind:kind atIndexPath:indexPath];
    if (!view)
        return;

    AAPLCollectionViewLayoutAttributes *attributes = [self layoutAttributesForSupplementaryItemOfKind:kind atIndexPath:indexPath];
    attributes = [attributes copy];
    attributes.shouldCalculateFittingSize = YES;

    UICollectionViewLayoutAttributes *newAttributes = [view preferredLayoutAttributesFittingAttributes:attributes];
    if (CGSizeEqualToSize(newAttributes.frame.size, attributes.frame.size))
        return;

    [self setSize:newAttributes.frame.size forElementOfKind:kind atIndexPath:indexPath invalidationContext:invalidationContext];
}

#pragma mark - AAPLLayoutAttributesLookup

- (AAPLCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryItemOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger sectionIndex = (indexPath.length == 1 ? AAPLGlobalSectionIndex : indexPath.section);
    AAPLLayoutSection *sectionInfo = [self sectionAtIndex:sectionIndex];
    return [sectionInfo layoutAttributesForSupplementaryItemOfKind:kind atIndexPath:indexPath];
}

- (AAPLCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger sectionIndex = (indexPath.length == 1 ? AAPLGlobalSectionIndex : indexPath.section);
    AAPLLayoutSection *sectionInfo = [self sectionAtIndex:sectionIndex];
    return [sectionInfo layoutAttributesForDecorationViewOfKind:kind atIndexPath:indexPath];
}

- (AAPLCollectionViewLayoutAttributes *)layoutAttributesForCellAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger sectionIndex = (indexPath.length == 1 ? AAPLGlobalSectionIndex : indexPath.section);
    AAPLLayoutSection *sectionInfo = [self sectionAtIndex:sectionIndex];
    return [sectionInfo layoutAttributesForCellAtIndexPath:indexPath];
}

@end
