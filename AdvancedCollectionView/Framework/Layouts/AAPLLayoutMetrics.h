/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import <UIKit/UIKit.h>

/// A variable height row. The row will be measured using the data source method -collectionView:sizeFittingSize:forItemAtIndexPath:
extern CGFloat const AAPLRowHeightVariable;

/// Rows with this height will have a height equal to the height of the collection view minus the initial vertical offset of the row. Really, only one cell should have this height set. Don't abuse this.
extern CGFloat const AAPLRowHeightRemainder;

extern CGFloat const AAPLRowHeightDefault;

typedef UICollectionReusableView *(^AAPLLayoutSupplementaryItemCreationBlock)(UICollectionView *collectionView, NSString *kind, NSString *identifier, NSIndexPath *indexPath);
typedef void (^AAPLLayoutSupplementaryItemConfigurationBlock)(id view, id dataSource, NSIndexPath *indexPath);

/// Definition of how supplementary views should be created and presented in a collection view.
@interface AAPLLayoutSupplementaryMetrics : NSObject <NSCopying>

- (id)initWithSupplementaryViewKind:(NSString *)kind NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSString *supplementaryViewKind;

/// Should this supplementary view be displayed while the placeholder is visible?
@property (nonatomic) BOOL visibleWhileShowingPlaceholder;

/// Should this supplementary view be pinned to the top of the view when scrolling? Only valid for header supplementary views.
@property (nonatomic) BOOL shouldPin;

/// The height of the supplementary view. If set to 0, the view will be measured to determine its optimal height.
@property (nonatomic) CGFloat height;

/// Should the supplementary view be hidden?
@property (nonatomic) BOOL hidden;

/// Use top & bottom padding to adjust spacing of header & footer elements. Not all headers & footers adhere to padding. Default is UIEdgeInsetsZero which is interpreted by supplementary items to be their default values.
@property (nonatomic) UIEdgeInsets padding;

/// How is this affected by other coinciding views?
@property (nonatomic) NSInteger zIndex;

/// The class to use when dequeuing an instance of this supplementary view
@property (nonatomic) Class supplementaryViewClass;

/// The background color that should be used for this supplementary view. If not set, this will be inherited from the section.
@property (nonatomic, strong) UIColor *backgroundColor;

/// The background color shown when this header is selected. If not set, this will be inherited from the section. Use [UIColor clearColor] instead of nil to override a selection color from the section (this will be translated into nil).
@property (nonatomic, strong) UIColor *selectedBackgroundColor;

/// Optional reuse identifier. If not specified, this will be inferred from the class of the supplementary view.
@property (nonatomic, copy) NSString *reuseIdentifier;

/// An optional block used to create an instance of the supplementary view.
@property (nonatomic, copy) AAPLLayoutSupplementaryItemCreationBlock createView;

/// Add a configuration block to the supplementary view. This does not clear existing configuration blocks.
- (void)configureWithBlock:(AAPLLayoutSupplementaryItemConfigurationBlock)block;

/// An block used to configure an instance of the supplementary view.
@property (nonatomic, copy) AAPLLayoutSupplementaryItemConfigurationBlock configureView;

@end

/// Definition of how a section within a collection view should be presented.
@interface AAPLLayoutSectionMetrics : NSObject <NSCopying>

/// The height of each row in the section. A value of AAPLRowHeightVariable will cause the layout to invoke -collectionView:sizeFittingSize:forItemAtIndexPath: on the data source for each cell. Sections will inherit a default value from the data source of 44.
@property (nonatomic) CGFloat rowHeight;

/// Padding around the cells for this section. The top & bottom padding will be applied between the headers & footers and the cells. The left & right padding will be applied between the view edges and the cells.
@property (nonatomic) UIEdgeInsets padding;

/// Insets for the separators drawn between rows.
@property (nonatomic) UIEdgeInsets separatorInsets;

/// Insets for the section separator drawn below this section
@property (nonatomic) UIEdgeInsets sectionSeparatorInsets;

/// The color to use for the background of a cell in this section
@property (nonatomic, strong) UIColor *backgroundColor;

/// The color to use when a cell becomes highlighted or selected
@property (nonatomic, strong) UIColor *selectedBackgroundColor;

/// The color to use when drawing the row separators.
@property (nonatomic, strong) UIColor *separatorColor;

/// The color to use when drawing the section separator below this section
@property (nonatomic, strong) UIColor *sectionSeparatorColor;

/// Should the section separator be shown at the bottom of the last section. Default is NO.
@property (nonatomic) BOOL showsSectionSeparatorWhenLastSection;

/// Create a new header associated with a specific data source
- (AAPLLayoutSupplementaryMetrics *)newHeader;

/// Create a new footer associated with a specific data source.
- (AAPLLayoutSupplementaryMetrics *)newFooter;

/// Update these metrics with the values from another metrics.
- (void)applyValuesFromMetrics:(AAPLLayoutSectionMetrics *)metrics;

/// Create a default metrics instance
+ (instancetype)defaultMetrics;

@property (nonatomic, copy) NSArray *supplementaryViews;
@property (nonatomic) BOOL hasPlaceholder;


@end
