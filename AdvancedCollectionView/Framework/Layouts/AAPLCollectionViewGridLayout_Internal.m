/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLCollectionViewGridLayout_Internal.h"

@implementation AAPLGridLayoutInvalidationContext

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    _invalidateLayoutMetrics = YES;
    return self;
}

@end

@implementation AAPLGridLayoutSupplementalItemInfo
@end

@implementation AAPLGridLayoutItemInfo
@end

@implementation AAPLGridLayoutRowInfo

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _items = [NSMutableArray array];
    return self;
}

@end


@implementation AAPLGridLayoutSectionInfo

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _rows = [NSMutableArray array];
    _items = [NSMutableArray array];
    _pinnableHeaderAttributes = [NSMutableArray array];

    return self;
}

- (NSMutableArray *)nonPinnableHeaderAttributes
{
    // Lazy initialise this, because it's only used for the global section
    if (_nonPinnableHeaderAttributes)
        return _nonPinnableHeaderAttributes;
    _nonPinnableHeaderAttributes = [NSMutableArray array];
    return _nonPinnableHeaderAttributes;
}

- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemAsPlaceholder
{
    AAPLGridLayoutSupplementalItemInfo *supplementalInfo = [[AAPLGridLayoutSupplementalItemInfo alloc] init];
    _placeholder = supplementalInfo;
    return supplementalInfo;
}

- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemAsHeader:(BOOL)header
{
    AAPLGridLayoutSupplementalItemInfo *supplementalInfo = [[AAPLGridLayoutSupplementalItemInfo alloc] init];
    if (header) {
        if (!_headers)
            _headers = [NSMutableArray array];
        [_headers addObject:supplementalInfo];
    }
    else {
        if (!_footers)
            _footers = [NSMutableArray array];
        [_footers addObject:supplementalInfo];
    }
    return supplementalInfo;
}

- (AAPLGridLayoutRowInfo *)addRow
{
    AAPLGridLayoutRowInfo *rowInfo = [[AAPLGridLayoutRowInfo alloc] init];
    [self.rows addObject:rowInfo];
    return rowInfo;
}

- (AAPLGridLayoutItemInfo *)addItem
{
    AAPLGridLayoutItemInfo *itemInfo = [[AAPLGridLayoutItemInfo alloc] init];
    [self.items addObject:itemInfo];
    return itemInfo;
}

- (CGFloat)columnWidth
{
    CGFloat width = self.layoutInfo.width;
    UIEdgeInsets margins = self.insets;
    CGFloat columnWidth = (width - margins.left - margins.right);
    return columnWidth;
}

/// Layout all the items in this section and return the total height of the section
- (void)computeLayoutWithOrigin:(CGFloat)start measureItemBlock:(AAPLLayoutMeasureBlock)measureItemBlock measureSupplementaryItemBlock:(AAPLLayoutMeasureBlock)measureSupplementaryItemBlock
{
    CGFloat width = self.layoutInfo.width;
    /// The height available to placeholder
    CGFloat availableHeight = self.layoutInfo.height - start;

    UIEdgeInsets margins = self.insets;
    NSInteger numberOfItems = [self.items count];
    CGFloat columnWidth = self.columnWidth;
    __block CGFloat rowHeight = 0;

    __block CGFloat originX = margins.left;
    __block CGFloat originY = start;

    // First lay out headers
    [self.headers enumerateObjectsUsingBlock:^(AAPLGridLayoutSupplementalItemInfo *headerInfo, NSUInteger headerIndex, BOOL *stop) {
        // skip headers if there are no items and the header isn't a global header
        if (!numberOfItems && !headerInfo.visibleWhileShowingPlaceholder)
            return;

        // skip headers that are hidden
        if (headerInfo.hidden)
            return;

        // This header needs to be measured!
        if (!headerInfo.height && measureSupplementaryItemBlock) {
            headerInfo.frame = CGRectMake(0, originY, width, UILayoutFittingExpandedSize.height);
            headerInfo.height = measureSupplementaryItemBlock(headerIndex, headerInfo.frame).height;
        }

        headerInfo.frame = CGRectMake(0, originY, width, headerInfo.height);
        originY += headerInfo.height;
    }];

    AAPLGridLayoutSupplementalItemInfo *placeholder = self.placeholder;
    if (placeholder) {
        // Height of the placeholder is equal to the height of the collection view minus the height of the headers
        CGFloat height = availableHeight - (originY - start);
        placeholder.height = height;
        placeholder.frame = CGRectMake(0, originY, width, height);
        originY += height;
    }

    // Next lay out all the items in rows
    [self.rows removeAllObjects];

    NSAssert(!placeholder || !numberOfItems, @"Can't have both a placeholder and items");

    // Lay out items and footers only if there actually ARE items.
    if (numberOfItems) {

        originY += margins.top;

        NSUInteger itemIndex = 0;
        NSEnumerator *itemEnumerator = self.items.objectEnumerator;
        AAPLGridLayoutItemInfo *item = [itemEnumerator nextObject];
        AAPLGridLayoutRowInfo *row = [self addRow];

        while (item) {
            BOOL needSizeUpdate = item.needSizeUpdate && measureItemBlock;

            CGFloat height = CGRectGetHeight(item.frame);
            if (AAPLRowHeightRemainder == item.frame.size.height) {
                height = self.layoutInfo.height - originY;
            }

			originY += rowHeight;
			rowHeight = 0;

			// only create a new row if there were items in the previous row.
			if ([row.items count])
				row = [self addRow];
			row.frame = CGRectMake(margins.left, originY, width, rowHeight);

            
            if (needSizeUpdate) {
                item.needSizeUpdate = NO;
                item.frame = CGRectMake(originX, originY, columnWidth, height);
                height = measureItemBlock(itemIndex, item.frame).height;
            }

            if (rowHeight < height)
                rowHeight = height;

			[row.items addObject:item];

			item.frame = CGRectMake(originX, originY, columnWidth, rowHeight);

			//            NSLog(@"item %d frame = %@", itemIndex, NSStringFromCGRect(item.frame));
			item = [itemEnumerator nextObject];

            // keep row height up to date
            CGRect rowFrame = row.frame;
            rowFrame.size.height = rowHeight;
            row.frame = rowFrame;

            ++itemIndex;
        }

        originY += rowHeight + margins.bottom;

        // lay out all footers
        for (AAPLGridLayoutSupplementalItemInfo *footerInfo in self.footers) {
            // skip hidden footers
            if (footerInfo.hidden)
                continue;
            // When showing the placeholder, we don't show footers
            CGFloat height = footerInfo.height;
            footerInfo.frame = CGRectMake(0, originY, width, height);
            originY += height;
        }

    }

    self.frame = CGRectMake(0, start, width, originY - start);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p %@>", NSStringFromClass([self class]), (__bridge void *)self, NSStringFromCGRect(_frame)];
}

#if DEBUG
- (NSString *)recursiveDescription __unused
{
    NSMutableString *result = [NSMutableString string];
    [result appendString:[self description]];

    if ([_headers count]) {
        [result appendString:@"\n    headers = @[\n"];

        for (AAPLGridLayoutSupplementalItemInfo *header in _headers) {
            [result appendFormat:@"        %@\n", header];
        }

        [result appendString:@"     ]"];
    }

    if (_placeholder) {
        [result appendFormat:@"\n    placeholder = %@", _placeholder];
    }

    if ([_rows count]) {
        [result appendString:@"\n    rows = @[\n"];

        NSArray *descriptions = [_rows valueForKey:@"recursiveDescription"];
        [result appendFormat:@"        %@\n", [descriptions componentsJoinedByString:@"\n        "]];
        [result appendString:@"    ]"];
    }

    return result;
}
#endif

@end



@implementation AAPLGridLayoutInfo

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    _sections = [NSMutableDictionary dictionary];
    return self;
}

- (AAPLGridLayoutSectionInfo *)addSectionWithIndex:(NSInteger)sectionIndex
{
    AAPLGridLayoutSectionInfo *section = [[AAPLGridLayoutSectionInfo alloc] init];
    section.layoutInfo = self;
    self.sections[@(sectionIndex)] = section;
    return section;
}

- (void)invalidate
{
    [self.sections removeAllObjects];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p width=%g height=%g contentOffsetY=%g>", NSStringFromClass([self class]), (__bridge void *)self, _width, _height, _contentOffsetY];
}

#if DEBUG
- (NSString *)recursiveDescription __unused
{
    NSMutableString *result = [NSMutableString string];
    [result appendString:[self description]];

    if ([_sections count]) {
        [result appendString:@"\n    sections = @[\n"];

        NSArray *descriptions = [_sections valueForKey:@"recursiveDescription"];
        [result appendFormat:@"        %@\n", [descriptions componentsJoinedByString:@"\n        "]];
        [result appendString:@"    ]"];
    }

    return result;
}
#endif

@end

@implementation AAPLIndexPathKind

- (instancetype)initWithIndexPath:(NSIndexPath *)indexPath kind:(NSString *)kind
{
	self = [super init];
	if (!self) return nil;
	
	_indexPath = indexPath;
	_kind = [kind copy];
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	return [[AAPLIndexPathKind alloc] initWithIndexPath:_indexPath kind:_kind];
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
	
	if (![object isKindOfClass:AAPLIndexPathKind.class])
		return NO;
	
	AAPLIndexPathKind *other = object;
	
	if (_indexPath == other->_indexPath && _kind == other->_kind)
		return YES;
	
	if (!_indexPath || ![_indexPath isEqual:other->_indexPath])
		return NO;
	
	return _kind && [_kind isEqualToString:other->_kind];
}

@end
