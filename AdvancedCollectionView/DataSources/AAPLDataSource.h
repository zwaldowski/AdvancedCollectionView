/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The base data source class. 
  
*/

#import <UIKit/UIKit.h>
#import "AAPLLayoutMetrics.h"
#import "AAPLContentLoading.h"

@class AAPLCollectionPlaceholderView;

@interface AAPLDataSource : NSObject <UICollectionViewDataSource, AAPLContentLoading>

- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// The title of this data source. This value is used to populate section headers and the segmented control tab.
@property (nonatomic, copy) NSString *title;

/// The number of sections in this data source.
@property (nonatomic, readonly) NSInteger numberOfSections;

/// Find the data source for the given section. Default implementation returns self.
- (AAPLDataSource *)dataSourceForSectionAtIndex:(NSInteger)sectionIndex;

/// Find the item at the specified index path.
- (id)itemAtIndexPath:(NSIndexPath *)indexPath;

/// Find the index paths of the specified item in the data source. An item may appear more than once in a given data source.
- (NSArray*)indexPathsForItem:(id)item;

/// Remove an item from the data source. This method should only be called as the result of a user action, such as tapping the "Delete" button in a swipe-to-delete gesture. Automatic removal of items due to outside changes should instead be handled by the data source itself — not the controller. Data sources must implement this to support swipe-to-delete.
- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath;

// Use these methods to notify the collection view of changes to the dataSource.
- (void)notifyItemsInsertedAtIndexPaths:(NSArray *)insertedIndexPaths;
- (void)notifyItemsRemovedAtIndexPaths:(NSArray *)removedIndexPaths;
- (void)notifyItemsRefreshedAtIndexPaths:(NSArray *)refreshedIndexPaths;
- (void)notifyItemMovedFromIndexPath:(NSIndexPath *)indexPath toIndexPaths:(NSIndexPath *)newIndexPath;

- (void)notifySectionsInserted:(NSIndexSet *)sections;
- (void)notifySectionsRemoved:(NSIndexSet *)sections;
- (void)notifySectionMovedFrom:(NSInteger)section to:(NSInteger)newSection;
- (void)notifySectionsRefreshed:(NSIndexSet *)sections;

- (void)notifyDidReloadData;

- (void)notifyBatchUpdate:(dispatch_block_t)update;
- (void)notifyBatchUpdate:(dispatch_block_t)update complete:(dispatch_block_t)complete;

- (void)notifyWillLoadContent;
- (void)notifyContentLoadedWithError:(NSError *)error;

#pragma mark - Metrics

@property (nonatomic, strong) AAPLLayoutSectionMetrics *defaultMetrics;

- (AAPLLayoutSectionMetrics *)metricsForSectionAtIndex:(NSInteger)sectionIndex;
- (void)setMetrics:(AAPLLayoutSectionMetrics *)metrics forSectionAtIndex:(NSInteger)sectionIndex;

/// Look up a header by its key
- (AAPLLayoutSupplementaryMetrics *)headerForKey:(NSString *)key;
/// Create a new header and append it to the collection of headers
- (AAPLLayoutSupplementaryMetrics *)newHeaderForKey:(NSString *)key;
/// Remove a header specified by its key
- (void)removeHeaderForKey:(NSString *)key;
/// Replace a header specified by its key with a new header with the same key.
- (void)replaceHeaderForKey:(NSString *)key withHeader:(AAPLLayoutSupplementaryMetrics *)header;

/// Create a new header for a specific section. This is a convenience method for adding a header via the section metrics.
- (AAPLLayoutSupplementaryMetrics *)newHeaderForSectionAtIndex:(NSInteger)sectionIndex;
/// Create a new footer for a specific section. This is a convenience method for adding a footer via the section metrics.
- (AAPLLayoutSupplementaryMetrics *)newFooterForSectionAtIndex:(NSInteger)sectionIndex;

/// Compute a flattened snapshot of the layout metrics associated with this and any child data sources.
- (NSDictionary *)snapshotMetrics;

#pragma mark - Placeholders

@property (nonatomic, copy) NSString *noContentTitle;
@property (nonatomic, copy) NSString *noContentMessage;
@property (nonatomic, strong) UIImage *noContentImage;

@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, copy) NSString *errorTitle;
@property (nonatomic, strong) UIImage *errorImage;

/// Is this data source "hidden" by a placeholder either of its own or from an enclosing data source. Use this to determine whether to report that there are no items in your data source while loading.
@property (nonatomic, readonly) BOOL obscuredByPlaceholder;

#pragma mark - Subclass hooks

/// Measure variable height cells. Variable height cells are not supported when there is more than one column. The goal here is to do the minimal necessary configuration to get the correct size information.
- (CGSize)collectionView:(UICollectionView *)collectionView sizeFittingSize:(CGSize)size forItemAtIndexPath:(NSIndexPath *)indexPath;

/// Determine whether or not a cell is editable. Default implementation returns YES.
- (BOOL)collectionView:(UICollectionView *)collectionView canEditItemAtIndexPath:(NSIndexPath *)indexPath;

/// Determine whether or not the cell is movable. Default implementation returns NO.
- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath;

/// Determine whether an item may be moved from its original location to a proposed location. Default implementation returns NO.
- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

/// Called by the collection view to alert the data source that an item has been moved. The data source should update its contents.
- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

/// Register reusable views needed by this data source
- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView NS_REQUIRES_SUPER;

/// Signal that the datasource SHOULD reload its content
- (void)setNeedsLoadContent;

/// Load the content of this data source.
- (void)loadContent;

/// Reset the content and loading state.
- (void)resetContent NS_REQUIRES_SUPER;

/// Use this method to wait for content to load. The block will be called once the loadingState has transitioned to the ContentLoaded, NoContent, or Error states. If the data source is already in that state, the block will be called immediately.
- (void)whenLoaded:(dispatch_block_t)block;

@end
