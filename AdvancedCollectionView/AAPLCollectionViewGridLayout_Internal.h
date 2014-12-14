/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
  
  This is an internal header with classes that are used to support the collection view layout.
  
 */

#import "AAPLCollectionViewGridLayout_Private.h"
#import "AAPLLayoutMetrics.h"

typedef CGSize (^AAPLLayoutMeasureBlock)(NSInteger itemIndex, CGRect frame);

@class AAPLGridLayoutSectionInfo;
@class AAPLGridLayoutRowInfo;
@class AAPLGridLayoutInfo;

/// Layout information about a supplementary item (header, footer, or placeholder)
@interface AAPLGridLayoutSupplementalItemInfo : NSObject
@property (nonatomic) CGRect frame;
@property (nonatomic) BOOL header;
@property (nonatomic) CGFloat height;
@property (nonatomic) BOOL shouldPin;
@property (nonatomic) BOOL visibleWhileShowingPlaceholder;
@property (nonatomic) BOOL isPlaceholder;
@property (nonatomic) UIColor *backgroundColor;
@property (nonatomic) UIColor *selectedBackgroundColor;
@property (nonatomic) BOOL hidden;
/// passed along to attributes
@property (nonatomic) UIEdgeInsets padding;
@end

/// Layout information about an item (cell)
@interface AAPLGridLayoutItemInfo : NSObject
@property (nonatomic) BOOL dragging;
@property (nonatomic) NSInteger columnIndex;
@property (nonatomic) CGRect frame;
@property (nonatomic) BOOL needSizeUpdate;
@end

/// Layout information about a row
@interface AAPLGridLayoutRowInfo : NSObject
@property (nonatomic) CGRect frame;
@property (nonatomic, strong) NSMutableArray *items;
@end

/// Layout information for a section
@interface AAPLGridLayoutSectionInfo : NSObject
@property (nonatomic) CGRect frame;
@property (nonatomic, weak) AAPLGridLayoutInfo *layoutInfo;
@property (nonatomic, readonly) NSMutableArray *rows;
@property (nonatomic, readonly) NSMutableArray *items;
@property (nonatomic, readonly) NSArray *headers;
@property (nonatomic, readonly) NSArray *footers;
@property (nonatomic, readonly) AAPLGridLayoutSupplementalItemInfo *placeholder;
@property (nonatomic) NSInteger numberOfColumns;
@property (nonatomic) UIEdgeInsets insets;

@property (nonatomic, readonly) CGRect headersRect;
@property (nonatomic, readonly) UIEdgeInsets groupPadding;
@property (nonatomic, readonly) UIEdgeInsets itemPadding;

@property (nonatomic) UIEdgeInsets separatorInsets;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) UIColor *selectedBackgroundColor;
@property (nonatomic, strong) UIColor *separatorColor;
@property (nonatomic) AAPLSeparatorOption separators;
@property (nonatomic) AAPLCellLayoutOrder cellLayoutOrder;
@property (nonatomic) NSUInteger phantomCellIndex;
@property (nonatomic) CGSize phantomCellSize;

@property (nonatomic, strong) NSMutableArray *pinnableHeaderAttributes;
@property (nonatomic, strong) NSMutableArray *nonPinnableHeaderAttributes;
@property (nonatomic, strong) AAPLCollectionViewGridLayoutAttributes *backgroundAttribute;

- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemOfKind:(NSString *)kind;
- (AAPLGridLayoutRowInfo *)addRow;
- (AAPLGridLayoutItemInfo *)addItem;
- (CGPoint)layoutSectionWithRect:(CGRect)viewport measureSupplement:(CGSize (^)(NSString *, NSUInteger, CGSize))measureSupplement measureItem:(CGSize (^)(NSUInteger, CGSize))measureItem;
@end
