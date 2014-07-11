/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLCollectionViewGridLayout.h"
#import "AAPLCollectionViewGridLayoutAttributes.h"
#import "AAPLDataSource_Private.h"
#import "AAPLLayoutMetrics.h"

typedef CGSize (^AAPLLayoutMeasureBlock)(NSUInteger itemIndex, CGRect frame);

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
@property (nonatomic) CGFloat height;
@property (nonatomic) BOOL shouldPin;
@property (nonatomic) BOOL visibleWhileShowingPlaceholder;
@property (nonatomic) UIColor *backgroundColor;
@property (nonatomic) UIColor *selectedBackgroundColor;
@property (nonatomic) BOOL hidden;
/// passed along to attributes
@property (nonatomic) UIEdgeInsets padding;
@end

/// Layout information about an item (cell)
@interface AAPLGridLayoutItemInfo : NSObject
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
@property (nonatomic) UIEdgeInsets insets;

@property (nonatomic) UIEdgeInsets separatorInsets;
@property (nonatomic) UIEdgeInsets sectionSeparatorInsets;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) UIColor *selectedBackgroundColor;
@property (nonatomic, strong) UIColor *separatorColor;
@property (nonatomic, strong) UIColor *sectionSeparatorColor;
@property (nonatomic) BOOL showsSectionSeparatorWhenLastSection;
@property (nonatomic, readonly) CGFloat columnWidth;

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

/// Used to look up supplementary & decoration attributes
@interface AAPLIndexPathKind : NSObject<NSCopying>

- (instancetype)initWithIndexPath:(NSIndexPath *)indexPath kind:(NSString *)kind;

@property (nonatomic, readonly) NSIndexPath *indexPath;
@property (nonatomic, readonly) NSString *kind;

@end
