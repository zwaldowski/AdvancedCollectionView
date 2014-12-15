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

@interface AAPLGridLayoutSectionInfo ()

@property (nonatomic, readonly) NSArray *footers;
@property (nonatomic, readonly) AAPLGridLayoutSupplementalItemInfo *placeholder;
@property (nonatomic, readonly) NSMutableDictionary *supplementalItemArraysByKind;

@end


@implementation AAPLGridLayoutSectionInfo

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
    return [self.supplementalItemArraysByKind[AAPLCollectionElementKindPlaceholder] firstObject];
}

- (NSArray *)headers
{
    return self.supplementalItemArraysByKind[UICollectionElementKindSectionHeader];
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
        self.supplementalItemArraysByKind[kind] = @[ supplementalInfo ];
    } else {
        supplementalInfo.header = [kind isEqual:UICollectionElementKindSectionHeader];

        NSMutableArray *items = self.supplementalItemArraysByKind[kind];
        if (!items) {
            items = [NSMutableArray array];
            self.supplementalItemArraysByKind[kind] = items;
        }
        
        [items addObject:supplementalInfo];
    }
    return supplementalInfo;
}

- (AAPLGridLayoutSupplementalItemInfo *)supplementalItemOfKind:(NSString *)kind atIndex:(NSUInteger)index {
    NSArray *items = self.supplementalItemArraysByKind[kind];
    if (index >= items.count) { return nil; }
    return items[index];
}

- (void)addItems:(NSInteger)count height:(CGFloat)height {
    BOOL variableRowHeight = _approxeq(height, AAPLRowHeightVariable);
    for (NSInteger i = 0; i < count; i++) {
        AAPLGridLayoutItemInfo *itemInfo = [[AAPLGridLayoutItemInfo alloc] init];
        itemInfo.frame = CGRectMake(0, 0, 0, height);
        if (variableRowHeight)
            itemInfo.needSizeUpdate = YES;
        [_items addObject:itemInfo];
    }
}

- (AAPLGridLayoutRowInfo *)addRow
{
    AAPLGridLayoutRowInfo *rowInfo = [[AAPLGridLayoutRowInfo alloc] init];
    [self.rows addObject:rowInfo];
    return rowInfo;
}

- (UIEdgeInsets)groupPadding {
    return AAPLInsetsWithout(self.insets, UIRectEdgeLeft | UIRectEdgeRight);
}

- (UIEdgeInsets)itemPadding {
    return AAPLInsetsWithout(self.insets, UIRectEdgeTop | UIRectEdgeBottom);
}

- (void)enumerateNonHeaderSupplementsPassingTest:(BOOL(^)(NSString *))kindTest usingBlock:(void(^)(AAPLGridLayoutSupplementalItemInfo *obj, NSString *kind, NSUInteger idx))block
{
    [self.supplementalItemArraysByKind enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSArray *objs, BOOL *stop) {
        if ([kind isEqual:UICollectionElementKindSectionHeader]) { return; }
        if (kindTest && !kindTest(kind)) { return; }
        [objs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stopB) {
            block(obj, kind, idx);
        }];
    }];
}

/// Layout all the items in this section and return the total height of the section
- (CGPoint)layoutSectionWithRect:(CGRect)viewport measureSupplement:(CGSize (^)(NSString *, NSUInteger, CGSize))measureSupplement measureItem:(CGSize (^)(NSUInteger, CGSize))measureItem
{
    UIEdgeInsets margins = self.insets;
    NSInteger numberOfItems = [self.items count];
    NSInteger numberOfColumns = self.numberOfColumns;
    CGFloat columnWidth = (CGRectGetWidth(viewport) - margins.left - margins.right) / numberOfColumns;
    
    __block CGFloat rowHeight = 0;
    __block CGPoint origin = CGPointMake(CGRectGetMinX(viewport) + margins.left, CGRectGetMinY(viewport));

    // First lay out headers
    CGFloat headerBeginY = origin.y;
    [self.headers enumerateObjectsUsingBlock:^(AAPLGridLayoutSupplementalItemInfo *headerInfo, NSUInteger headerIndex, BOOL *stop) {
        // skip headers if there are no items and the header isn't a global header
        if (!numberOfItems && !headerInfo.visibleWhileShowingPlaceholder)
            return;

        // skip headers that are hidden
        if (headerInfo.hidden)
            return;

        // This header needs to be measured!
        if (!headerInfo.height && measureSupplement) {
            headerInfo.frame = CGRectMake(0, 0, CGRectGetWidth(viewport), UILayoutFittingExpandedSize.height);
            headerInfo.height = measureSupplement(UICollectionElementKindSectionHeader, headerIndex, headerInfo.frame.size).height;
        }

        headerInfo.frame = CGRectMake(0, origin.y, CGRectGetWidth(viewport), headerInfo.height);
        origin.y += headerInfo.height;
    }];
    
    _headersRect = CGRectMake(0, headerBeginY, CGRectGetWidth(viewport), origin.y - headerBeginY);

    AAPLGridLayoutSupplementalItemInfo *placeholder = self.placeholder;
    if (placeholder) {
        // Height of the placeholder is equal to the height of the collection view minus the height of the headers
        CGFloat height = CGRectGetHeight(viewport) - (origin.y - CGRectGetMinY(viewport));
        placeholder.height = height;
        placeholder.frame = CGRectMake(0, origin.y, CGRectGetWidth(viewport), height);
        origin.y += height;
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

        origin.y += margins.top;

        NSInteger columnIndex = 0;
        NSInteger itemIndex = 0;
        NSEnumerator *itemEnumerator = self.items.objectEnumerator;
        AAPLGridLayoutItemInfo *item = [itemEnumerator nextObject];
        AAPLGridLayoutRowInfo *row = [self addRow];

        while (item) {
            BOOL phantomCell = (itemIndex == _phantomCellIndex);
            BOOL hiddenCell = item.dragging;
            BOOL needSizeUpdate = item.needSizeUpdate && measureItem;

            CGFloat height = CGRectGetHeight(item.frame);
            
            if (hiddenCell) {
                [row.items addObject:item];
                item.frame = (CGRect){ origin, { columnWidth, height }};
                item.columnIndex = NSNotFound;
                item = [itemEnumerator nextObject];
                ++itemIndex;
                continue;
            }

            if (!(columnIndex % numberOfColumns)) {
                origin.y += rowHeight;
                rowHeight = 0;
                columnIndex = 0;
                
                if (leftToRight) {
                    origin.x = margins.left;
                } else {
                    origin.x = CGRectGetWidth(viewport) - margins.right - columnWidth;
                }

                // only create a new row if there were items in the previous row.
                if ([row.items count])
                    row = [self addRow];
                row.frame = CGRectMake(margins.left, origin.y, CGRectGetWidth(viewport), rowHeight);
                //                NSLog(@"row %d frame = %@", (itemIndex / numberOfColumns), NSStringFromCGRect(row.frame));
            }

            
            if (phantomCell)
                height = _phantomCellSize.height;
            else if (needSizeUpdate) {
                item.needSizeUpdate = NO;
                item.frame = (CGRect){ origin, { columnWidth, UILayoutFittingExpandedSize.height }};
                height = measureItem(itemIndex, item.frame.size).height;
            }

            if (rowHeight < height)
                rowHeight = height;

            if (!phantomCell) {
                [row.items addObject:item];

                item.frame = (CGRect){ origin, { columnWidth, rowHeight }};
                item.columnIndex = columnIndex;

                //            NSLog(@"item %d frame = %@", itemIndex, NSStringFromCGRect(item.frame));
                item = [itemEnumerator nextObject];
            }

            // keep row height up to date
            CGRect rowFrame = row.frame;
            rowFrame.size.height = rowHeight;
            row.frame = rowFrame;

            if (leftToRight) {
                origin.x += columnWidth;
            } else {
                origin.x -= columnWidth;
            }

            ++columnIndex;
            ++itemIndex;
        }

        origin.y += rowHeight + margins.bottom;

        // lay out all footers
        for (AAPLGridLayoutSupplementalItemInfo *footerInfo in self.footers) {
            // skip hidden footers
            if (footerInfo.hidden)
                continue;
            // When showing the placeholder, we don't show footers
            CGFloat height = footerInfo.height;
            footerInfo.frame = CGRectMake(0, origin.y, CGRectGetWidth(viewport), height);
            origin.y += height;
        }

    }

    self.frame = (CGRect){ viewport.origin, { CGRectGetWidth(viewport), origin.y - CGRectGetMinY(viewport) }};
    
    CGPoint ret = CGPointMake(CGRectGetMaxX(viewport), origin.y);
    
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

    [self.supplementalItemArraysByKind enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSArray *items, BOOL *__unused stop) {
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

@implementation AAPLIndexPathKind
- (instancetype)initWithIndexPath:(NSIndexPath *)indexPath kind:(NSString *)kind
{
    self = [super init];
    if (!self) { return nil; }
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
