/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLCollectionViewGridLayout_Internal.h"

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
	_supplementalItemArraysByKind = [NSMutableDictionary dictionary];
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

- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemOfKind:(NSString *)supplementalKind
{
	AAPLGridLayoutSupplementalItemInfo *supplementalInfo = [[AAPLGridLayoutSupplementalItemInfo alloc] init];
	NSMutableArray *items = _supplementalItemArraysByKind[supplementalKind];
	if (!items) {
		items = [NSMutableArray array];
		_supplementalItemArraysByKind[supplementalKind] = items;
	}
	[items addObject:supplementalInfo];
	return supplementalInfo;
}

- (void)enumerateArraysOfOtherSupplementalItems:(void(^)(NSString *kind, NSArray *items, BOOL *stop))block
{
	NSParameterAssert(block != nil);
	[_supplementalItemArraysByKind enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSArray *items, BOOL *stahp) {
		if ([kind isEqual:UICollectionElementKindSectionHeader] || [kind isEqual:UICollectionElementKindSectionFooter]) return;
		block(kind, items, stahp);
	}];
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
- (void)computeLayoutWithOrigin:(CGFloat)start measureItem:(AAPLLayoutMeasureBlock)measureItemBlock measureSupplementaryItem:(AAPLLayoutMeasureKindBlock)measureSupplementaryItemBlock
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

	NSArray *headers = _supplementalItemArraysByKind[UICollectionElementKindSectionHeader], *footers = _supplementalItemArraysByKind[UICollectionElementKindSectionFooter];

	// First lay out headers
	[headers enumerateObjectsUsingBlock:^(AAPLGridLayoutSupplementalItemInfo *headerInfo, NSUInteger headerIndex, BOOL *stop) {
		// skip headers if there are no items and the header isn't a global header
		if (!numberOfItems && !headerInfo.visibleWhileShowingPlaceholder)
			return;

		// skip headers that are hidden
		if (headerInfo.hidden)
			return;

		// This header needs to be measured!
		if (!headerInfo.height && measureSupplementaryItemBlock) {
			headerInfo.frame = CGRectMake(0, originY, width, UILayoutFittingExpandedSize.height);
			headerInfo.height = measureSupplementaryItemBlock(UICollectionElementKindSectionHeader, headerIndex, headerInfo.frame).height;
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
	[_rows removeAllObjects];

	NSAssert(!placeholder || !numberOfItems, @"Can't have both a placeholder and items");

	// Lay out items, footers, and misc. items only if there actually ARE items.
	if (numberOfItems) {
		CGFloat contentBeginY = originY + margins.top;
		__block CGFloat backgroundEndY = contentBeginY;

		[_supplementalItemArraysByKind enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSArray *obj, BOOL *stopA) {
			if ([kind isEqual:UICollectionElementKindSectionHeader] || [kind isEqual:UICollectionElementKindSectionFooter]) { return; }

			originY = contentBeginY;

			[obj enumerateObjectsUsingBlock:^(AAPLGridLayoutSupplementalItemInfo *item, NSUInteger itemIndex, BOOL *stopb) {

				// skip hidden supplementary items
				if (item.hidden)
					return;

				// This header needs to be measured!
				if (!item.height && measureSupplementaryItemBlock) {
					item.frame = CGRectMake(0, originY, width, UILayoutFittingExpandedSize.height);
					item.height = measureSupplementaryItemBlock(kind, itemIndex, item.frame).height;
				}

				item.frame = CGRectMake(0, originY, width, item.height);
				originY += item.height;

				backgroundEndY = MAX(backgroundEndY, originY);
			}];

		}];

		originY = contentBeginY;

		__block AAPLGridLayoutRowInfo *row = [self addRow];
		[self.items enumerateObjectsUsingBlock:^(AAPLGridLayoutItemInfo *item, NSUInteger itemIndex, BOOL *stop) {
			BOOL needSizeUpdate = item.needSizeUpdate && measureItemBlock;

			CGFloat height = CGRectGetHeight(item.frame);
			if (AAPLRowHeightRemainder == item.frame.size.height) {
				height = self.layoutInfo.height - originY;
			}

			originY += rowHeight;
			rowHeight = 0;

			// only create a new row if there were items in the previous row.
			if (_rows.count)
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

			// keep row height up to date
			CGRect rowFrame = row.frame;
			rowFrame.size.height = rowHeight;
			row.frame = rowFrame;
		}];

		originY = MAX(backgroundEndY, originY) + margins.bottom;

		// lay out all footers
		for (AAPLGridLayoutSupplementalItemInfo *footerInfo in footers) {
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
	return [NSString stringWithFormat:@"<%@: %p %@>", NSStringFromClass(self.class), (__bridge void *)self, NSStringFromCGRect(_frame)];
}

#if DEBUG
- (NSString *)recursiveDescription __unused
{
    NSMutableString *result = [NSMutableString string];
    [result appendString:[self description]];

	NSArray *headers = _supplementalItemArraysByKind[UICollectionElementKindSectionHeader];
	NSArray *footers = _supplementalItemArraysByKind[UICollectionElementKindSectionFooter];
	NSUInteger others = _supplementalItemArraysByKind.count - (headers ? 1 : 0) - (footers ? 1 : 0);

	if (headers.count) {
        [result appendString:@"\n    headers = @[\n"];

		for (AAPLGridLayoutSupplementalItemInfo *header in headers) {
            [result appendFormat:@"        %@\n", header];
        }

        [result appendString:@"     ]"];
    }

    if (_placeholder) {
        [result appendFormat:@"\n    placeholder = %@", _placeholder];
    }

	if (_rows.count) {
        [result appendString:@"\n    rows = @[\n"];

		NSArray *descriptions = [_rows valueForKey:@"recursiveDescription"];
        [result appendFormat:@"        %@\n", [descriptions componentsJoinedByString:@"\n        "]];
        [result appendString:@"    ]"];
	}

	if (footers.count) {
		[result appendString:@"\n    footers = @[\n"];
		for (AAPLGridLayoutSupplementalItemInfo *footer in footers) {
			[result appendFormat:@"        %@\n", footer];
		}
		[result appendString:@"     ]"];
	}

	if (others) {
		[result appendString:@"\n    others = @[\n"];

		[self enumerateArraysOfOtherSupplementalItems:^(NSString *kind, NSArray *items, BOOL *stahp) {
			[result appendFormat:@"        %@ = @[\n", kind];

			for (AAPLGridLayoutSupplementalItemInfo *item in items) {
				[result appendFormat:@"            %@\n", item];
			}

			[result appendString:@"         ]\n"];
		}];

		[result appendString:@"     ]"];
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
	
	_indexPath = [indexPath copy];
	_kind = [kind copy];
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
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
