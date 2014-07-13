/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLCollectionViewGridLayout.h"
#import "AAPLCollectionViewGridLayoutAttributes.h"
#import "AAPLDataSourceDelegate.h"
#import "AAPLLayoutMetrics.h"

typedef CGSize (^AAPLLayoutMeasureBlock)(NSUInteger itemIndex, CGRect frame);
typedef CGSize (^AAPLLayoutMeasureKindBlock)(NSString *kind, NSUInteger itemIndex, CGRect frame);

@class AAPLGridLayoutInfo;

/// Layout information about a supplementary item (header, footer, or placeholder)
@interface AAPLGridLayoutSupplementalItemInfo : NSObject
@property (nonatomic) CGRect frame;
@property (nonatomic) CGFloat height;
@property (nonatomic) BOOL shouldPin;
@property (nonatomic) BOOL visibleWhileShowingPlaceholder;
@property (nonatomic) UIColor *backgroundColor;
@property (nonatomic) UIColor *selectedBackgroundColor;
@property (nonatomic) BOOL hidden;
@property (nonatomic) UIEdgeInsets padding;
@property (nonatomic) NSInteger zIndex;

@end

/// Layout information about an item (cell)
@interface AAPLGridLayoutItemInfo : NSObject

@property (nonatomic) CGRect frame;
@property (nonatomic) BOOL needSizeUpdate;

@end

/// Layout information for a section
@interface AAPLGridLayoutSectionInfo : NSObject
@property (nonatomic) CGRect frame;
@property (nonatomic, weak) AAPLGridLayoutInfo *layoutInfo;

@property (nonatomic, readonly) NSMutableArray *items;
@property (nonatomic, readonly) NSMutableDictionary *supplementalItemArraysByKind;
- (void)enumerateArraysOfOtherSupplementalItems:(void(^)(NSString *kind, NSArray *items, BOOL *stop))block;
@property (nonatomic, readonly) AAPLGridLayoutSupplementalItemInfo *placeholder;
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

- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemOfKind:(NSString *)kind;
- (AAPLGridLayoutSupplementalItemInfo *)addSupplementalItemAsPlaceholder;
- (AAPLGridLayoutItemInfo *)addItem;

- (void)computeLayoutWithOrigin:(CGPoint)start measureItem:(AAPLLayoutMeasureBlock)measureItemBlock measureSupplementaryItem:(AAPLLayoutMeasureKindBlock)measureSupplementaryItemBlock;

@end

/// The layout information
@interface AAPLGridLayoutInfo : NSObject

@property (nonatomic) CGSize size;
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
