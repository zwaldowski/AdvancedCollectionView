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

- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemOfKind:(NSString *)kind
{
    AAPLGridLayoutSupplementalItemInfo *supplementalInfo = [[AAPLGridLayoutSupplementalItemInfo alloc] init];
    if ([kind isEqualToString:AAPLCollectionElementKindPlaceholder]) {
        self.supplementalItemArraysByKind[kind] = @[ supplementalInfo ];
    } else {
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

- (CGRectEdge)effectiveHorizontalSlicingEdge
{
    switch (_cellLayoutOrder) {
        case AAPLCellLayoutOrderLeadingToTrailing:
            return (UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionLeftToRight) ? CGRectMinXEdge : CGRectMaxXEdge;
        case AAPLCellLayoutOrderTrailingToLeading:
            return (UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) ? CGRectMinXEdge : CGRectMaxXEdge;
        case AAPLCellLayoutOrderRightToLeft:
            return CGRectMaxXEdge;
        default:
            return CGRectMinXEdge;
    }
}

/// Layout all the items in this section and return the total height of the section
- (CGPoint)layoutSectionWithRect:(CGRect)viewport measureSupplement:(CGSize (^)(NSString *, NSUInteger, CGSize))measureSupplement measureItem:(CGSize (^)(NSUInteger, CGSize))measureItem
{
    [self.rows removeAllObjects];

    NSInteger numberOfItems = [self.items count];
    NSInteger numberOfColumns = self.numberOfColumns;
    
    __block CGRect layoutRect = viewport;
    layoutRect.size.height = CGRectGetHeight(CGRectInfinite);

    // First lay out headers
    CGFloat headerBeginY = CGRectGetMinY(layoutRect);
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
        
        CGRect newFrame;
        CGRectDivide(layoutRect, &newFrame, &layoutRect, headerInfo.height, CGRectMinYEdge);
        headerInfo.frame = newFrame;
    }];
    
    _headersRect = CGRectMake(0, headerBeginY, CGRectGetWidth(viewport), CGRectGetMinY(layoutRect) - headerBeginY);
    
    if (numberOfItems && !self.placeholder) {
        // Lay out items and footers only if there actually ARE items.
        __block CGRect itemsLayoutRect = UIEdgeInsetsInsetRect(layoutRect, self.groupPadding);
        __block CGRect activeItemRect = CGRectZero;
        __block CGRect activeRowRect = CGRectZero;
        __block NSInteger columnIndex = 0;
        __block AAPLGridLayoutRowInfo *row = nil;

        CGFloat itemsBeginY = CGRectGetMinY(itemsLayoutRect);
        CGFloat columnWidth = CGRectGetWidth(itemsLayoutRect) / numberOfColumns;
        CGRectEdge divideFrom = [self effectiveHorizontalSlicingEdge];
        
        void(^updateRowHeight)(CGFloat) = ^(CGFloat itemHeight){
            CGRect rowFrame = row.frame;
            
            if (!CGRectIsEmpty(rowFrame) && CGRectGetHeight(rowFrame) >= itemHeight) { return; }
            
            CGRect appendRect;
            CGRectDivide(itemsLayoutRect, &appendRect, &itemsLayoutRect, itemHeight - CGRectGetHeight(rowFrame), CGRectMinYEdge);
            if (CGRectEqualToRect(rowFrame, CGRectZero)) {
                rowFrame = appendRect;
            } else {
                rowFrame = CGRectUnion(rowFrame, appendRect);
            }
            
            row.frame = activeRowRect = rowFrame;
            
            for (AAPLGridLayoutItemInfo *item in row.items) {
                CGRect itemFrame = item.frame;
                itemFrame.size.height = itemHeight;
                item.frame = itemFrame;
            }
        };
        
        void(^advanceColumn)(void) = ^{
            CGRectDivide(activeRowRect, &activeItemRect, &activeRowRect, columnWidth, divideFrom);
            ++columnIndex;
        };
        
        void(^beginRow)(void) = ^{
            columnIndex = -1;
            if (!row || row.items.count) {
                row = [self addRow];
            }
            updateRowHeight(0);
            advanceColumn();
        };
        
        CGRect(^itemRect)(CGFloat) = ^(CGFloat itemHeight) {
            return (CGRect){ activeItemRect.origin, { activeItemRect.size.width, itemHeight }};
        };
        
        beginRow();
        
        [self.items enumerateObjectsUsingBlock:^(AAPLGridLayoutItemInfo *item, NSUInteger itemIndex, BOOL *stop) {
            void(^pushItem)(CGFloat, NSUInteger) = ^(CGFloat height, NSUInteger column){
                [row.items addObject:item];
                item.frame = itemRect(height);
                item.columnIndex = column;
            };
            
            CGFloat height = CGRectGetHeight(item.frame);

            BOOL needSizeUpdate = item.needSizeUpdate && measureItem;
            
            if (!(columnIndex % numberOfColumns)) {
                beginRow();
            }
            
            if (needSizeUpdate) {
                item.needSizeUpdate = NO;
                item.frame = itemRect(UILayoutFittingExpandedSize.height);
                height = measureItem(itemIndex, item.frame.size).height;
            }
            
            CGFloat rowHeight = fmax(height, CGRectGetHeight(row.frame));
            
            // keep row height up to date
            updateRowHeight(rowHeight);
            
            pushItem(rowHeight, columnIndex);
            
            advanceColumn();
        }];
        
        CGFloat itemsHeight = CGRectGetMinY(itemsLayoutRect) - itemsBeginY;
        CGRect itemsRect;
        CGRectDivide(layoutRect, &itemsRect, &layoutRect, itemsHeight, CGRectMinYEdge);

        // lay out all footers
        for (AAPLGridLayoutSupplementalItemInfo *footerInfo in self.footers) {
            // skip hidden footers
            if (footerInfo.hidden)
                continue;
            
            // When showing the placeholder, we don't show footers
            CGRect newFrame;
            CGRectDivide(layoutRect, &newFrame, &layoutRect, footerInfo.height, CGRectMinYEdge);
            footerInfo.frame = newFrame;
        }
    } else if (!numberOfItems && self.placeholder) {
        // Height of the placeholder is equal to the height of the collection view minus the height of the headers
        CGRect frame = CGRectIntersection(layoutRect, viewport);
        CGFloat height = CGRectGetHeight(frame);
        self.placeholder.height = CGRectGetHeight(frame);
        self.placeholder.frame = frame;
        
        CGRect unused;
        CGRectDivide(layoutRect, &unused, &layoutRect, height, CGRectMinYEdge);
    }

    self.frame = (CGRect){ viewport.origin, { CGRectGetWidth(viewport), CGRectGetMinY(layoutRect) - CGRectGetMinY(viewport) }};
    
    CGPoint ret = CGPointMake(CGRectGetMaxX(layoutRect), CGRectGetMinY(layoutRect));
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
