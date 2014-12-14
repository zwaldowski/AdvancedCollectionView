/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
  
  This file contains implementations of the internal classes used by AAPLCollectionViewGridLayout to build the layout.
  
 */

#import "AAPLCollectionViewGridLayout_Internal.h"
#import "AAPLMath.h"

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


@implementation AAPLGridLayoutSectionInfo {
    NSMutableDictionary *_supplementalItemArraysByKind;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _rows = [NSMutableArray array];
    _items = [NSMutableArray array];
    _numberOfColumns = 1;
    _phantomCellIndex = NSNotFound;
    _phantomCellSize = CGSizeZero;
    _pinnableHeaderAttributes = [NSMutableArray array];
    _supplementalItemArraysByKind = NSMutableDictionary.new;

    return self;
}

- (AAPLGridLayoutSupplementalItemInfo *)placeholder
{
    return [_supplementalItemArraysByKind[AAPLCollectionElementKindPlaceholder] firstObject];
}

- (NSArray *)headers
{
    return [NSArray arrayWithArray:_supplementalItemArraysByKind[UICollectionElementKindSectionHeader]];
}

- (NSArray *)footers
{
    return [NSArray arrayWithArray:_supplementalItemArraysByKind[UICollectionElementKindSectionFooter]];
}

- (NSMutableArray *)nonPinnableHeaderAttributes
{
    // Lazy initialise this, because it's only used for the global section
    if (_nonPinnableHeaderAttributes)
        return _nonPinnableHeaderAttributes;
    _nonPinnableHeaderAttributes = [NSMutableArray array];
    return _nonPinnableHeaderAttributes;
}

- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemOfKind:(NSString *)kind
{
    AAPLGridLayoutSupplementalItemInfo *supplementalInfo = [[AAPLGridLayoutSupplementalItemInfo alloc] init];
    if ([kind isEqualToString:AAPLCollectionElementKindPlaceholder]) {
        supplementalInfo.isPlaceholder = YES;
        _supplementalItemArraysByKind[kind] = @[ supplementalInfo ];
    } else {
        supplementalInfo.header = [kind isEqual:UICollectionElementKindSectionHeader];

        NSMutableArray *items = _supplementalItemArraysByKind[kind];
        if (!items) {
            items = [NSMutableArray array];
            _supplementalItemArraysByKind[kind] = items;
        }
        
        [items addObject:supplementalInfo];
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
    NSInteger numberOfColumns = self.numberOfColumns;
    CGFloat columnWidth = (width - margins.left - margins.right) / numberOfColumns;
    return columnWidth;
}

- (UIEdgeInsets)groupPadding {
    return AAPLInsetsWithout(self.insets, UIRectEdgeLeft | UIRectEdgeRight);
}

- (UIEdgeInsets)itemPadding {
    return AAPLInsetsWithout(self.insets, UIRectEdgeTop | UIRectEdgeBottom);
}

/// Layout all the items in this section and return the total height of the section
- (CGPoint)computeLayoutWithOrigin:(CGFloat)start measureItemBlock:(AAPLLayoutMeasureBlock)measureItemBlock measureSupplementaryItemBlock:(AAPLLayoutMeasureBlock)measureSupplementaryItemBlock
{
    CGFloat width = self.layoutInfo.width;
    /// The height available to placeholder
    CGFloat availableHeight = self.layoutInfo.height - start;

    UIEdgeInsets margins = self.insets;
    NSInteger numberOfItems = [self.items count];
    NSInteger numberOfColumns = self.numberOfColumns;
    CGFloat columnWidth = self.columnWidth;
    __block CGFloat rowHeight = 0;

    __block CGFloat originX = margins.left;
    __block CGFloat originY = start;

    // First lay out headers
    const CGFloat headerBeginY = originY;
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
    
    _headersRect = CGRectMake(0, headerBeginY, width, originY - headerBeginY);

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
    
    BOOL leftToRight;
    switch (_cellLayoutOrder) {
        case AAPLCellLayoutOrderLeadingToTrailing:
            leftToRight = UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionLeftToRight;
            break;
        case AAPLCellLayoutOrderTrailingToLeading:
            leftToRight = UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
            break;
        case AAPLCellLayoutOrderLeftToRight:
            leftToRight = YES;
            break;
        case AAPLCellLayoutOrderRightToLeft:
            leftToRight = NO;
            break;
    }

    // Lay out items and footers only if there actually ARE items.
    if (numberOfItems) {

        originY += margins.top;

        NSInteger columnIndex = 0;
        NSInteger itemIndex = 0;
        NSEnumerator *itemEnumerator = self.items.objectEnumerator;
        AAPLGridLayoutItemInfo *item = [itemEnumerator nextObject];
        AAPLGridLayoutRowInfo *row = [self addRow];

        while (item) {
            BOOL phantomCell = (itemIndex == _phantomCellIndex);
            BOOL hiddenCell = item.dragging;
            BOOL needSizeUpdate = item.needSizeUpdate && measureItemBlock;

            CGFloat height = CGRectGetHeight(item.frame);
            if (_approxeq(CGRectGetHeight(item.frame), AAPLRowHeightRemainder)) {
                height = self.layoutInfo.height - originY;
            }
            
            if (hiddenCell) {
                [row.items addObject:item];
                item.frame = CGRectMake(originX, originY, columnWidth, height);
                item.columnIndex = NSNotFound;
                item = [itemEnumerator nextObject];
                ++itemIndex;
                continue;
            }

            if (!(columnIndex % numberOfColumns)) {
                originY += rowHeight;
                rowHeight = 0;
                columnIndex = 0;
                
                if (leftToRight) {
                    originX = margins.left;
                } else {
                    originX = width - margins.right - columnWidth;
                }

                // only create a new row if there were items in the previous row.
                if ([row.items count])
                    row = [self addRow];
                row.frame = CGRectMake(margins.left, originY, width, rowHeight);
                //                NSLog(@"row %d frame = %@", (itemIndex / numberOfColumns), NSStringFromCGRect(row.frame));
            }

            
            if (phantomCell)
                height = _phantomCellSize.height;
            else if (needSizeUpdate) {
                item.needSizeUpdate = NO;
                item.frame = CGRectMake(originX, originY, columnWidth, height);
                height = measureItemBlock(itemIndex, item.frame).height;
            }

            if (rowHeight < height)
                rowHeight = height;

            if (!phantomCell) {
                [row.items addObject:item];

                item.frame = CGRectMake(originX, originY, columnWidth, rowHeight);
                item.columnIndex = columnIndex;

                //            NSLog(@"item %d frame = %@", itemIndex, NSStringFromCGRect(item.frame));
                item = [itemEnumerator nextObject];
            }

            // keep row height up to date
            CGRect rowFrame = row.frame;
            rowFrame.size.height = rowHeight;
            row.frame = rowFrame;

            if (leftToRight) {
                originX += columnWidth;
            } else {
                originX -= columnWidth;
            }

            ++columnIndex;
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
    
    CGPoint ret = CGPointMake(width, originY);
    
    return ret;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p %@>", NSStringFromClass([self class]), self, NSStringFromCGRect(_frame)];
}

- (NSString *)recursiveDescription
{
    NSMutableString *result = [NSMutableString string];
    [result appendString:[self description]];

    if ([_rows count]) {
        [result appendString:@"\n    rows = @[\n"];

        NSArray *descriptions = [_rows valueForKey:@"recursiveDescription"];
        [result appendFormat:@"        %@\n", [descriptions componentsJoinedByString:@"\n        "]];
        [result appendString:@"    ]"];
    }

    [result appendString:@"\n    supplements = @[\n"];

    [_supplementalItemArraysByKind enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSArray *items, BOOL *__unused stop) {
        [result appendFormat:@"        %@ = @[\n", kind];

        for (AAPLGridLayoutSupplementalItemInfo *item in items) {
            [result appendFormat:@"            %@\n", item];
        }

        [result appendString:@"         ]\n"];
    }];

    [result appendString:@"     ]"];

    return result;
}
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
    return [NSString stringWithFormat:@"<%@: %p width=%g height=%g contentOffsetY=%g>", NSStringFromClass([self class]), self, _width, _height, _contentOffsetY];
}

- (NSString *)recursiveDescription
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
@end
