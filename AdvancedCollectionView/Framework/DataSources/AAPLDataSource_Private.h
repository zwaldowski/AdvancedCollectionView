/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The base data source class.
 
  This file contains methods used internally by subclasses. These methods are not considered part of the public API of AAPLDataSource. It is possible to implement fully functional data sources without using these methods.
 */

#import "AAPLDataSource.h"
#import "AAPLDataSourceMetrics_Private.h"

NS_ASSUME_NONNULL_BEGIN




@protocol AAPLDataSourceDelegate;
@class AAPLCollectionPlaceholderView;

typedef NS_ENUM(NSInteger, AAPLDataSourceSectionOperationDirection) {
    AAPLDataSourceSectionOperationDirectionNone = 0,
    AAPLDataSourceSectionOperationDirectionLeft,
    AAPLDataSourceSectionOperationDirectionRight,
} ;



@interface AAPLDataSourcePlaceholder ()
/// Is this placeholder an activity indicator?
@property (nonatomic) BOOL activityIndicator;

/// Create a placeholder that shows an activity indicator
+ (instancetype)placeholderWithActivityIndicator;

@end



@interface AAPLDataSource ()
/// Create an instance of the placeholder view for this data source.
- (AAPLCollectionPlaceholderView *)dequeuePlaceholderViewForCollectionView:(UICollectionView *)collectionView atIndexPath:(NSIndexPath *)indexPath;

/// Compute a flattened snapshot of the layout metrics associated with this and any child data sources.
- (NSDictionary<NSNumber *, AAPLDataSourceSectionMetrics *> *)snapshotMetrics;

/// Create a flattened snapshop of the layout metrics for the specified section. This resolves metrics from parent and child data sources.
- (AAPLDataSourceSectionMetrics *)snapshotMetricsForSectionAtIndex:(NSInteger)sectionIndex;

/// Should an activity indicator be displayed while we're refreshing the content. Default is NO.
@property (nonatomic, readonly) BOOL showsActivityIndicatorWhileRefreshingContent;

/// Will this data source show an activity indicator given its current state?
@property (nonatomic, readonly) BOOL shouldShowActivityIndicator;

/// Will this data source show a placeholder given its current state?
@property (nonatomic, readonly) BOOL shouldShowPlaceholder;

/// Load the content of this data source.
- (void)loadContent;
/// The internal method which is actually called by loadContent. This allows subclasses to perform pre- and post-loading activities.
- (void)beginLoadingContentWithProgress:(AAPLLoadingProgress *)progress;
/// The internal method called when loading is complete. Subclasses may implement this method to provide synchronisation of child data sources.
- (void)endLoadingContentWithState:(NSString *)state error:(nullable NSError *)error update:(dispatch_block_t)update;

/// Display an activity indicator for this data source. If sections is nil, display the activity indicator for the entire data source. The sections must be contiguous.
- (void)presentActivityIndicatorForSections:(nullable NSIndexSet *)sections;

/// Display a placeholder for this data source. If sections is nil, display the placeholder for the entire data source. The sections must be contiguous.
- (void)presentPlaceholder:(nullable AAPLDataSourcePlaceholder *)placeholder forSections:(nullable NSIndexSet *)sections;

/// Dismiss a placeholder or activity indicator
- (void)dismissPlaceholderForSections:(nullable NSIndexSet *)sections;

/// Update the placeholder view for a given section.
- (void)updatePlaceholderView:(AAPLCollectionPlaceholderView *)placeholderView forSectionAtIndex:(NSInteger)sectionIndex;

/// State machine delegate method for notifying that the state is about to change. This is used to update the loadingState property.
- (void)stateWillChange;
/// State machine delegate method for notifying that the state has changed. This is used to update the loadingState property.
- (void)stateDidChange;

/// Return the number of headers associated with the section.
- (NSInteger)numberOfHeadersInSectionAtIndex:(NSInteger)sectionIndex includeChildDataSouces:(BOOL)includeChildDataSources;
/// Return the number of footers associated with the section.
- (NSInteger)numberOfFootersInSectionAtIndex:(NSInteger)sectionIndex includeChildDataSouces:(BOOL)includeChildDataSources;

/// Returns NSIndexPath instances any occurrences of the supplementary metrics in this data source. If the supplementary metrics are part of the default metrics for the data source, an NSIndexPath for each section will be returned. Returns an empty array if the supplementary metrics are not found.
- (NSArray<NSIndexPath *> *)indexPathsForSupplementaryItem:(AAPLSupplementaryItem *)supplementaryItem header:(BOOL)header;

/// The block will only be called if the supplementary item is found.
- (void)findSupplementaryItemForHeader:(BOOL)header indexPath:(NSIndexPath *)indexPath usingBlock:(void(^)(AAPLDataSource *dataSource, NSIndexPath *localIndexPath, AAPLSupplementaryItem *supplementaryItem))block;

/// Get an index path for the data source represented by the global index path. This works with -dataSourceForSectionAtIndex:.
- (NSIndexPath *)localIndexPathForGlobalIndexPath:(NSIndexPath *)globalIndexPath;

/// Is this data source the root data source? This depends on proper set up of the delegate property. Container data sources ALWAYS act as the delegate for their contained data sources.
@property (nonatomic, readonly, getter = isRootDataSource) BOOL rootDataSource;

/// A delegate object that will receive change notifications from this data source.
@property (nullable, nonatomic, weak) id<AAPLDataSourceDelegate> delegate;

/// Notify the parent data source that this data source will load its content. Unlike other notifications, this notification will not be propagated past the parent data source.
- (void)notifyWillLoadContent;

/// Notify the parent data source that this data source has finished loading its content with the given error (nil if no error). Unlike other notifications, this notification will not propagate past the parent data source.
- (void)notifyContentLoadedWithError:(NSError *)error;

- (void)notifySectionsInserted:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)notifySectionsRemoved:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)notifySectionMovedFrom:(NSInteger)section to:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction;

- (void)notifyContentUpdatedForSupplementaryItem:(AAPLSupplementaryItem *)metrics atIndexPaths:(NSArray *)indexPaths header:(BOOL)header;

@end



@protocol AAPLDataSourceDelegate <NSObject>
@optional

- (void)dataSource:(AAPLDataSource *)dataSource didInsertItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)dataSource:(AAPLDataSource *)dataSource didRemoveItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)dataSource:(AAPLDataSource *)dataSource didRefreshItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)dataSource:(AAPLDataSource *)dataSource didMoveItemAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)newIndexPath;

- (void)dataSource:(AAPLDataSource *)dataSource didInsertSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)dataSource:(AAPLDataSource *)dataSource didRemoveSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)dataSource:(AAPLDataSource *)dataSource didMoveSection:(NSInteger)section toSection:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)dataSource:(AAPLDataSource *)dataSource didRefreshSections:(NSIndexSet *)sections;

- (void)dataSourceDidReloadData:(AAPLDataSource *)dataSource;
- (void)dataSource:(AAPLDataSource *)dataSource performBatchUpdate:(dispatch_block_t)update complete:(dispatch_block_t)complete;

/// If the content was loaded successfully, the error will be nil.
- (void)dataSource:(AAPLDataSource *)dataSource didLoadContentWithError:(NSError *)error;

/// Called just before a datasource begins loading its content.
- (void)dataSourceWillLoadContent:(AAPLDataSource *)dataSource;

/// Present an activity indicator. The sections must be contiguous.
- (void)dataSource:(AAPLDataSource *)dataSource didPresentActivityIndicatorForSections:(NSIndexSet *)sections;

/// Present a placeholder for a set of sections. The sections must be contiguous.
- (void)dataSource:(AAPLDataSource *)dataSource didPresentPlaceholderForSections:(NSIndexSet *)sections;

/// Remove a placeholder for a set of sections.
- (void)dataSource:(AAPLDataSource *)dataSource didDismissPlaceholderForSections:(NSIndexSet *)sections;

/// Update the view or views associated with supplementary item at given index paths
- (void)dataSource:(AAPLDataSource *)dataSource didUpdateSupplementaryItem:(AAPLSupplementaryItem *)supplementaryItem atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths header:(BOOL)header;

@end




NS_ASSUME_NONNULL_END
