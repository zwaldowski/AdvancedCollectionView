/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import <UIKit/UIKit.h>
#import "AAPLLayoutMetrics.h"
#import "AAPLContentLoading.h"

@class AAPLCollectionPlaceholderView;

typedef enum {
	AAPLDataSourceSectionOperationDirectionNone,
	AAPLDataSourceSectionOperationDirectionRight,
	AAPLDataSourceSectionOperationDirectionLeft
} AAPLDataSourceSectionOperationDirection;

@interface AAPLDataSource : NSObject <UICollectionViewDataSource, AAPLContentLoading>

- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// The title of this data source. This value is used to populate section headers.
@property (nonatomic, copy) NSString *title;

/// The number of sections in this data source.
@property (nonatomic, readonly) NSUInteger numberOfSections;

/// Find the data source for the given section. Default implementation returns self.
- (AAPLDataSource *)dataSourceForSectionAtIndex:(NSInteger)sectionIndex;

/// Find the item at the specified index path.
- (id)itemAtIndexPath:(NSIndexPath *)indexPath;

/// Find the index paths of the specified item in the data source. An item may appear more than once in a given data source.
- (NSArray*)indexPathsForItem:(id)item;

/// Remove an item from the data source. This method should only be called as the result of a user action. Automatic removal of items due to outside changes should instead be handled by the data source itself — not the controller.
- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath;

// Use these methods to notify the collection view of changes to the dataSource.
- (void)notifyItemsInsertedAtIndexPaths:(NSArray *)insertedIndexPaths;
- (void)notifyItemsRemovedAtIndexPaths:(NSArray *)removedIndexPaths;
- (void)notifyItemsRefreshedAtIndexPaths:(NSArray *)refreshedIndexPaths;
- (void)notifyItemMovedFromIndexPath:(NSIndexPath *)indexPath toIndexPaths:(NSIndexPath *)newIndexPath;

- (void)notifySectionsInserted:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)notifySectionsRemoved:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)notifySectionMovedFrom:(NSInteger)section to:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)notifySectionsRefreshed:(NSIndexSet *)sections;

- (void)notifyDidReloadData;

- (void)notifyBatchUpdate:(dispatch_block_t)update complete:(dispatch_block_t)complete;

- (void)notifyWillLoadContent;
- (void)notifyContentLoadedWithError:(NSError *)error;

#pragma mark - Metrics

@property (nonatomic, strong) AAPLLayoutSectionMetrics *defaultMetrics;

- (AAPLLayoutSectionMetrics *)metricsForSectionAtIndex:(NSInteger)sectionIndex;
- (void)setMetrics:(AAPLLayoutSectionMetrics *)metrics forSectionAtIndex:(NSInteger)sectionIndex __unused;

/// Look up a header by its key
- (AAPLLayoutSupplementaryMetrics *)headerForKey:(NSString *)key;
/// Create a new header and append it to the collection of headers
- (AAPLLayoutSupplementaryMetrics *)newHeaderForKey:(NSString *)key;
/// Remove a header specified by its key
- (void)removeHeaderForKey:(NSString *)key __unused;
/// Replace a header specified by its key with a new header with the same key.
- (void)replaceHeaderForKey:(NSString *)key withHeader:(AAPLLayoutSupplementaryMetrics *)header __unused;

/// Compute a flattened snapshot of the layout metrics associated with this and any child data sources.
- (NSDictionary *)snapshotMetrics;

#pragma mark - Placeholders

@property (nonatomic, copy) NSString *noContentTitle;
@property (nonatomic, copy) NSString *noContentMessage;
@property (nonatomic, strong) UIImage *noContentImage;

@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, copy) NSString *errorTitle;

/// Is this data source "hidden" by a placeholder either of its own or from an enclosing data source. Use this to determine whether to report that there are no items in your data source while loading.
@property (nonatomic, readonly) BOOL obscuredByPlaceholder;

#pragma mark - Subclass hooks

/// Measure variable height cells. The goal here is to do the minimal necessary configuration to get the correct size information.
- (CGSize)collectionView:(UICollectionView *)collectionView sizeFittingSize:(CGSize)size forItemAtIndexPath:(NSIndexPath *)indexPath;

/// Register reusable views needed by this data source
- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView NS_REQUIRES_SUPER;

/// Signal that the data source SHOULD reload its content
- (void)setNeedsLoadContent;

/// Load the content of this data source.
- (void)loadContent;

/// Reset the content and loading state.
- (void)resetContent NS_REQUIRES_SUPER;

/// Use this method to wait for content to load. The block will be called once the loadingState has transitioned to the ContentLoaded, NoContent, or Error states. If the data source is already in that state, the block will be called immediately.
- (void)whenLoaded:(dispatch_block_t)block __unused;

#pragma mark -

- (void)stateWillChangeFrom:(NSString *)oldState to:(NSString *)newState NS_REQUIRES_SUPER;
- (void)stateDidChangeFrom:(NSString *)oldState to:(NSString *)newState NS_REQUIRES_SUPER;


@end
