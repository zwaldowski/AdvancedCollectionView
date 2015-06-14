/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Classes used to define the layout metrics.
 */

@import UIKit;

NS_ASSUME_NONNULL_BEGIN




/// The element kind for placeholders. In general, it's unlikely this will be needed.
extern NSString * const AAPLCollectionElementKindPlaceholder;

/// A marker value for elements that should be sized automatically based on their constraints.
extern CGFloat const AAPLCollectionViewAutomaticHeight;

/// The index of the global header & footer section
extern NSInteger const AAPLGlobalSectionIndex;

typedef NS_ENUM(NSInteger, AAPLCellLayoutOrder) {
    AAPLCellLayoutOrderLeftToRight,
    AAPLCellLayoutOrderRightToLeft,
} ;

@class AAPLDataSource;
@class AAPLTheme;

typedef void (^AAPLSupplementaryItemConfigurationBlock)(__kindof UICollectionReusableView *view, __kindof AAPLDataSource *dataSource, NSIndexPath *indexPath);

/// Definition of how supplementary views should be created and presented in a collection view.
@interface AAPLSupplementaryItem : NSObject <NSCopying>

/// Should this supplementary view be displayed while the placeholder is visible?
@property (nonatomic, getter = isVisibleWhileShowingPlaceholder) BOOL visibleWhileShowingPlaceholder;

/// Should this supplementary view be pinned to the top of the view when scrolling? Only valid for header supplementary views.
@property (nonatomic) BOOL shouldPin;

/// The height of the supplementary view. Default value is AAPLCollectionViewAutomaticHeight. Setting this property to a concrete value will prevent the supplementary view from being automatically sized.
@property (nonatomic) CGFloat height;

/// The estimated height of the supplementary view. To prevent layout glitches, this value should be set to the best estimation of the height of the supplementary view.
@property (nonatomic) CGFloat estimatedHeight;

/// Should the supplementary view be hidden?
@property (nonatomic, getter = isHidden) BOOL hidden;

/// Use top & bottom layoutMargin to adjust spacing of header & footer elements. Not all headers & footers adhere to layoutMargins. Default is UIEdgeInsetsZero which is interpretted by supplementary items to be their default values.
@property (nonatomic) UIEdgeInsets layoutMargins;

/// The class to use when dequeuing an instance of this supplementary view
@property (nonatomic) Class supplementaryViewClass;

/// The background color that should be used for this supplementary view. If not set, this will be inherited from the section.
@property (nonatomic, strong) UIColor *backgroundColor;

/// The background color shown when this header is selected. If not set, this will be inherited from the section. This will only be used when simulatesSelection is YES.
@property (nonatomic, strong) UIColor *selectedBackgroundColor;

/// The color to use for the background when the supplementary view has been pinned. If not set, this will be inherrited from the section's backgroundColor value.
@property (nonatomic, strong) UIColor *pinnedBackgroundColor;

/// The color to use when showing the bottom separator line (if shown). If not set, this will be inherited from the section.
@property (nonatomic, strong) UIColor *separatorColor;

/// The color to use when showing the bottom separator line if the supplementary view has been pinned. If not set, this will be inherited from the section's separatorColor value.
@property (nonatomic, strong) UIColor *pinnedSeparatorColor;

/// Should the header/footer show a separator line? The default value is NO. When shown, the separator will be shown using the separator color.
@property (nonatomic) BOOL showsSeparator;

/// Should this header simulate selection highlighting like cells? The default value is NO.
@property (nonatomic) BOOL simulatesSelection;

/// The represented element kind of this supplementary view. Default is UICollectionElementKindSectionHeader.
@property (nonatomic, readonly, copy) NSString *elementKind;

/// Optional reuse identifier. If not specified, this will be inferred from the class of the supplementary view.
@property (null_resettable, nonatomic, copy) NSString *reuseIdentifier;

/// A block that can be used to configure the supplementary view after it is created.
@property (nullable, nonatomic, copy) AAPLSupplementaryItemConfigurationBlock configureView;

/// Add a configuration block to the supplementary view. This does not clear existing configuration blocks.
- (void)configureWithBlock:(AAPLSupplementaryItemConfigurationBlock)block;

/// Update these metrics with the values from another metrics.
- (void)applyValuesFromMetrics:(AAPLSupplementaryItem *)metrics;

@end



/// Definition of how a section within a collection view should be presented.
@interface AAPLSectionMetrics : NSObject <NSCopying>

/// The height of each row in the section. The default value is AAPLCollectionViewAutomaticHeight. Setting this property to a concrete value will prevent rows from being sized automatically using autolayout.
@property (nonatomic) CGFloat rowHeight;

/// The estimated height of each row in the section. The default value is 44pts. The closer the estimatedRowHeight value matches the actual value of the row height, the less change will be noticed when rows are resized.
@property (nonatomic) CGFloat estimatedRowHeight;

/// Number of columns in this section. Sections will inherit a default of 1 from the data source.
@property (nonatomic) NSInteger numberOfColumns;

/// Padding around the cells for this section. The top & bottom padding will be applied between the headers & footers and the cells. The left & right padding will be applied between the view edges and the cells.
@property (nonatomic) UIEdgeInsets padding;

/// Layout margins for cells in this section. When not set (e.g. UIEdgeInsetsZero), the default value of the theme will be used, listLayoutMargins.
@property (nonatomic) UIEdgeInsets layoutMargins;

/// Should a column separator be drawn. Default is YES.
@property (nonatomic) BOOL showsColumnSeparator;

/// Should a row separator be drawn. Default is NO.
@property (nonatomic) BOOL showsRowSeparator;

/// Should separators be drawn between sections. Default is NO.
@property (nonatomic) BOOL showsSectionSeparator;

/// Should the section separator be shown at the bottom of the last section. Default is NO.
@property (nonatomic) BOOL showsSectionSeparatorWhenLastSection;

/// Insets for the separators drawn between rows (left & right) and columns (top & bottom).
@property (nonatomic) UIEdgeInsets separatorInsets;

/// Insets for the section separator drawn below this section
@property (nonatomic) UIEdgeInsets sectionSeparatorInsets;

/// The color to use for the background of a cell in this section
@property (nonatomic, strong) UIColor *backgroundColor;

/// The color to use when a cell becomes highlighted or selected
@property (nonatomic, strong) UIColor *selectedBackgroundColor;

/// The color to use when drawing the row separators (and column separators when numberOfColumns > 1 && showsColumnSeparator == YES).
@property (nonatomic, strong) UIColor *separatorColor;

/// The color to use when drawing the section separator below this section.
@property (nonatomic, strong) UIColor *sectionSeparatorColor;

/// How the cells should be laid out when there are multiple columns. The current default is AAPLCellLayoutOrderLeftToRight, but it SHOULD be AAPLCellLayoutLeadingToTrailing.
@property (nonatomic) AAPLCellLayoutOrder cellLayoutOrder;

/// The default theme that should be passed to cells & supplementary views. The default value is an instance of AAPLTheme.
@property (nonatomic) AAPLTheme *theme;

/// Update these metrics with the values from another metrics.
- (void)applyValuesFromMetrics:(AAPLSectionMetrics *)metrics;

/// Resolve any missing property values from the theme if possible.
- (void)resolveMissingValuesFromTheme;


@end




NS_ASSUME_NONNULL_END
