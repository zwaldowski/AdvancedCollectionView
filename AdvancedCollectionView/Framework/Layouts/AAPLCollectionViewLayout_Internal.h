/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
 
  This is an internal header with classes that are used to support the collection view layout.
 */

#import "AAPLCollectionViewLayout_Private.h"
#import "AAPLLayoutMetrics.h"

#define DEFAULT_ZINDEX 1
#define SEPARATOR_ZINDEX 100
#define SECTION_SEPARATOR_ZINDEX 2000
#define HEADER_ZINDEX 1000
#define PINNED_HEADER_ZINDEX 10000

#define SECTION_SEPARATOR_TOP 0
#define SECTION_SEPARATOR_BOTTOM 1

@class AAPLLayoutSection;
@class AAPLLayoutRow;
@class AAPLLayoutInfo;




@protocol AAPLLayoutAttributesResolving <NSObject>
- (AAPLCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryItemOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;
- (AAPLCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;
- (AAPLCollectionViewLayoutAttributes *)layoutAttributesForCellAtIndexPath:(NSIndexPath *)indexPath;
@end




@protocol AAPLGridLayoutObject<NSObject>
@property (nonatomic) CGRect frame;
@property (nonatomic) NSInteger itemIndex;
@property (nonatomic, readonly) NSIndexPath *indexPath;
@property (nonatomic, strong) AAPLCollectionViewLayoutAttributes *layoutAttributes;

/// Update the frame of this object. If the frame has changed, mark the object as invalid in the invalidation context.
- (void)setFrame:(CGRect)frame invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext;
@end




/// Layout information about a supplementary item (header, footer)
@interface AAPLLayoutSupplementaryItem : AAPLSupplementaryItem <AAPLGridLayoutObject, NSCopying>
@property (nonatomic, weak) AAPLLayoutSection *section;
@end




/// Layout information for a placeholder
@interface AAPLLayoutPlaceholder : NSObject <AAPLGridLayoutObject, NSCopying>

@property (nonatomic) UIColor *backgroundColor;
@property (nonatomic) CGFloat height;
@property (nonatomic) BOOL hasEstimatedHeight;

/// The first section index of this placeholder
@property (nonatomic, readonly) NSInteger startingSectionIndex;

/// The last section index of this placeholder
@property (nonatomic, readonly) NSInteger endingSectionIndex;

@end




/// Layout information about an item (cell)
@interface AAPLLayoutCell : NSObject <AAPLGridLayoutObject, NSCopying>
@property (nonatomic, weak) AAPLLayoutRow *row;
@property (nonatomic) BOOL dragging;
@property (nonatomic) NSInteger columnIndex;
@property (nonatomic) BOOL hasEstimatedHeight;
@end




/// Layout information about a row
@interface AAPLLayoutRow : NSObject <NSCopying>
@property (nonatomic) CGRect frame;
@property (nonatomic, strong, readonly) NSArray<AAPLLayoutCell *> *items;
@property (nonatomic, weak, readonly) AAPLLayoutSection *section;
@property (nonatomic, strong) AAPLCollectionViewLayoutAttributes *rowSeparatorLayoutAttributes;

- (void)addItem:(AAPLLayoutCell *)item;

/// Update the frame of this grouped object and any child objects. Use the invalidation context to mark layout objects as invalid.
- (void)setFrame:(CGRect)frame invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext;

@end




/// Layout information for a section
@interface AAPLLayoutSection : AAPLSectionMetrics <AAPLLayoutAttributesResolving, NSCopying>
@property (nonatomic) CGRect frame;
@property (nonatomic) NSInteger sectionIndex;

@property (nonatomic, readonly, getter = isGlobalSection) BOOL globalSection;

@property (nonatomic, weak) AAPLLayoutInfo *layoutInfo;
@property (nonatomic, strong) NSMutableArray *rows;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSMutableArray *headers;
@property (nonatomic, strong) NSMutableArray *footers;

@property (nonatomic, readonly) CGFloat columnWidth;
@property (nonatomic) NSInteger phantomCellIndex;
@property (nonatomic) CGSize phantomCellSize;

/// Should the column separator be shown based on all factors
@property (nonatomic, readonly) BOOL shouldShowColumnSeparator;

@property (nonatomic, strong) AAPLCollectionViewLayoutAttributes *backgroundAttribute;

@property (nonatomic, strong) AAPLLayoutPlaceholder *placeholderInfo;

@property (nonatomic, readonly) NSArray<AAPLLayoutSupplementaryItem *> *pinnableHeaders;
@property (nonatomic, readonly) NSArray<AAPLLayoutSupplementaryItem *> *nonPinnableHeaders;

/// The height of the non-pinning headers
@property (nonatomic, readonly) CGFloat heightOfNonPinningHeaders;

- (void)addSupplementaryItem:(AAPLLayoutSupplementaryItem *)supplementaryItem;
- (void)addRow:(AAPLLayoutRow *)row;
- (void)addItem:(AAPLLayoutCell *)item;

/// Update the frame of this grouped object and any child objects. Use the invalidation context to mark layout objects as invalid.
- (void)setFrame:(CGRect)frame invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext;

/// Enumerate ALL the layout attributes associated with this section
- (void)enumerateLayoutAttributesWithBlock:(void(^)(AAPLCollectionViewLayoutAttributes *layoutAttributes, BOOL *stop))block;

/// Layout this section with the given starting origin and using the invalidation context to record cells and supplementary views that should be redrawn.
- (CGFloat)layoutWithOrigin:(CGFloat)originY invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext;

/// Reset the content of this section
- (void)reset;

@end




/// The layout information
@interface AAPLLayoutInfo : NSObject <AAPLLayoutAttributesResolving, NSCopying>
@property (nonatomic) CGSize collectionViewSize;
@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat height;
/// The additional height that's available to placeholders
@property (nonatomic) CGFloat heightAvailableForPlaceholders;
@property (nonatomic) CGFloat contentOffsetY;
@property (nonatomic, readonly, weak) AAPLCollectionViewLayout *layout;

@property (nonatomic, readonly) NSInteger numberOfSections;
@property (nonatomic, readonly) BOOL hasGlobalSection;

- (instancetype)initWithLayout:(__weak AAPLCollectionViewLayout *)layout NS_DESIGNATED_INITIALIZER;

/// Return the layout section with the given sectionIndex.
- (AAPLLayoutSection *)sectionAtIndex:(NSInteger)sectionIndex;
/// Create and add a new section with the given section index. The value of sectionIndex MUST equal numberOfSections or an assertion will be raised. It might be beneficial in the future to allow sections to be inserted out of order and cleaned up in -finalizeLayout.
- (AAPLLayoutSection *)newSectionWithIndex:(NSInteger)sectionIndex;

/// Enumerate the sections using a block. If a global section exists, the block will be called first with the global section. Then the block will be called once for each section in the layout. Setting the output parameter stop to YES will cancel enumeration.
- (void)enumerateSectionsWithBlock:(void(^)(NSInteger sectionIndex, AAPLLayoutSection *sectionInfo, BOOL *stop))block;

/// Create a new placeholder covering the specified range of sections.
- (AAPLLayoutPlaceholder *)newPlaceholderStartingAtSectionIndex:(NSInteger)sectionIndex;

/// Remove all sections including the global section, thus invalidating all layout information.
- (void)invalidate;

/// Finalise the layout. This method adjusts the size of placeholders and calls each sections -finalizeLayoutAttributesForSectionsWithContent: method.
- (void)finalizeLayout;

/// Update the size of an item and mark it as invalidated in the given invalidationContext. This is needed for self-sizing view support. This method also adjusts the position of any content effected by the size change.
- (void)setSize:(CGSize)size forItemAtIndexPath:(NSIndexPath *)indexPath invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext;
/// Update the size of a supplementary item and mark it as invalidated in the given invalidationContext. This is needed for self-sizing view support. This method also adjusts the position of any content effected by the size change.
- (void)setSize:(CGSize)size forElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext;

/// Invalidate the current size information for the item at the given indexPath, update the layout possibly adjusting the position of content that needs to move to make room for or take up room from the item.
- (void)invalidateMetricsForItemAtIndexPath:(NSIndexPath *)indexPath invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext;
/// Invalidate the current size information for the supplementary item with the given elementKind and indexPath. This also updates the layout to adjust the position of any content that might need to move to make room for or take up room from the adjusted supplementary item.
- (void)invalidateMetricsForElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath invalidationContext:(UICollectionViewLayoutInvalidationContext *)invalidationContext;


- (instancetype)init NS_UNAVAILABLE;
@end
