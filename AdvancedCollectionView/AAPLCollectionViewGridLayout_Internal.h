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

/// A subclass of UICollectionViewLayoutInvalidationContext that adds invalidation for metrics and origin
@interface AAPLGridLayoutInvalidationContext : UICollectionViewLayoutInvalidationContext
@property (nonatomic) BOOL invalidateLayoutMetrics;
@property (nonatomic) BOOL invalidateLayoutOrigin;
@end

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
@property (nonatomic, strong) NSMutableArray *rows;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSMutableArray *headers;
@property (nonatomic, strong) NSMutableArray *footers;
@property (nonatomic, strong) AAPLGridLayoutSupplementalItemInfo *placeholder;
@property (nonatomic) NSInteger numberOfColumns;
@property (nonatomic) UIEdgeInsets insets;

@property (nonatomic) UIEdgeInsets separatorInsets;
@property (nonatomic) UIEdgeInsets sectionSeparatorInsets;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) UIColor *selectedBackgroundColor;
@property (nonatomic, strong) UIColor *separatorColor;
@property (nonatomic, strong) UIColor *sectionSeparatorColor;
@property (nonatomic) BOOL showsColumnSeparator;
@property (nonatomic) BOOL showsSectionSeparatorWhenLastSection;
@property (nonatomic) AAPLCellLayoutOrder cellLayoutOrder;
@property (nonatomic) CGFloat columnWidth;
@property (nonatomic) NSUInteger phantomCellIndex;
@property (nonatomic) CGSize phantomCellSize;

@property (nonatomic, strong) NSMutableArray *pinnableHeaderAttributes;
@property (nonatomic, strong) NSMutableArray *nonPinnableHeaderAttributes;
@property (nonatomic, strong) AAPLCollectionViewGridLayoutAttributes *backgroundAttribute;

- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemAsHeader:(BOOL)header;
- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemAsPlaceholder;
- (AAPLGridLayoutRowInfo *)addRow;
- (AAPLGridLayoutItemInfo *)addItem;
- (void)computeLayoutWithOrigin:(CGFloat)originY measureItemBlock:(AAPLLayoutMeasureBlock)itemBlock measureSupplementaryItemBlock:(AAPLLayoutMeasureBlock)supplementaryBlock;
@end

/// The layout information
@interface AAPLGridLayoutInfo : NSObject
@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGFloat contentOffsetY;
@property (nonatomic, strong) NSMutableDictionary *sections;

- (AAPLGridLayoutSectionInfo *)addSectionWithIndex:(NSInteger)sectionIndex;

- (void)invalidate;

@end
