/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The base data source class.
 */

#import "AAPLLayoutMetrics.h"
#import "AAPLContentLoading.h"

NS_ASSUME_NONNULL_BEGIN




@class AAPLAction;



/**
 A general purpose placeholder class for representing the no content or error message placeholders in a data source.
 */
@interface AAPLDataSourcePlaceholder : NSObject <NSCopying>

/// The title of the placeholder. This is typically displayed larger than the message.
@property (nullable, nonatomic, copy) NSString *title;
/// The message of the placeholder. This is typically displayed in using a smaller body font.
@property (nullable, nonatomic, copy) NSString *message;
/// An image for the placeholder. This is displayed above the title.
@property (nullable, nonatomic, strong) UIImage *image;

/// Method for creating a placeholder. One of title or message must not be nil.
+ (instancetype)placeholderWithTitle:(nullable NSString *)title message:(nullable NSString *)message image:(nullable UIImage *)image;

@end



/**
 The AAPLDataSource class is a concrete implementation of the `UICollectionViewDataSource` protocol designed to support composition and sophisticated layout delegated to individual sections of the data source.

 At a minimum, subclasses should implement the following methods for managing items:

 - -numberOfSections
 - -itemAtIndexPath:
 - -indexPathsForItem:
 - -removeItemAtIndexPath:
 - -numberOfItemsInSection:

 Subclasses should implement `-registerReusableViewsWithCollectionView:` to register their views for cells. Note, calling super is mandatory to ensure all views for headers and footers are properly registered. For example:

     -(void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
     {
         [super registerReusableViewsWithCollectionView:collectionView];
         [collectionView registerCell:[MyCell class] forCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(MyCell)];
     }

     Subclasses will need to implement the `UICollectionView` data source method `-collectionView:cellForItemAtIndexPath:` to return a configured cell. For example:

     -(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
     {
         MyCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(MyCell) forIndexPath:indexPath];
         MyItem *item = [self itemAtIndexPath:indexPath];
         // ... configure the cell with the item
         return cell;
     }

 For subclasses that need to load their content, implementing `-loadContentWithProgress:` is the answer. This method will always be called as the data source transitions from the initial state (`AAPLLoadStateInitial`) to the content loaded state (`AAPLLoadStateContentLoaded`). The default implementation simply calls the complete method on the progress object to transition into the content loaded state. Subclasses can implement more complex loading logic. For example:

     -(void)loadContentWithProgress:(AAPLLoadingProgress *)progress
     {
         [ServerManager fetchMyItemsWithCompletionHandler:^(NSArray<MyItem *> *items, NSError *error) {
             if (progress.cancelled)
                 return;

             if (error) {
                 [progress completeWithError:error];
                 return;
             }

             // It's important to only reference the data source via the parameter to prevent creation of retain cycles
             [progress updateWithContent:^(MyDataSource *me) {
                 // store the items
             }];
         }];
     }

 */
@interface AAPLDataSource <ItemType : id> : NSObject <UICollectionViewDataSource, AAPLContentLoading>

/// Designated initialiser for a data source.
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// The title of this data source. This value is used to populate section headers and the segmented control tab.
@property (nullable, nonatomic, copy) NSString *title;

/// The number of sections in this data source.
@property (nonatomic, readonly) NSInteger numberOfSections;

/// Return the number of items in a specific section. Implement this instead of the UICollectionViewDataSource method.
- (NSInteger)numberOfItemsInSection:(NSInteger)sectionIndex;

/// Find the data source for the given section. Default implementation returns self.
- (AAPLDataSource *)dataSourceForSectionAtIndex:(NSInteger)sectionIndex;

/// Find the item at the specified index path. Returns nil when indexPath does not specify a valid item in the data source.
- (nullable ItemType)itemAtIndexPath:(NSIndexPath *)indexPath;

/// Find the index paths of the specified item in the data source. An item may appear more than once in a given data source.
- (NSArray<NSIndexPath *>*)indexPathsForItem:(ItemType)item;

/// Remove an item from the data source. This method should only be called as the result of a user action, such as tapping the "Delete" button in a swipe-to-delete gesture. Automatic removal of items due to outside changes should instead be handled by the data source itself — not the controller. Data sources must implement this to support swipe-to-delete.
- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath;

/// The primary actions that may be performed on the item at the given indexPath. These actions may change depending on the state of the item, therefore, they should not be cached except during presentation. These actions are shown on the right side of the cell. Default implementation returns an empty array.
- (NSArray<AAPLAction *> *)primaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath;

/// Secondary actions that may be performed on the item at an index path. These actions may change depending on the state of the item, therefore, they should not be cached except during presentation. These actions are shown on the left side of the cell. Default implementation returns an empty array.
- (NSArray<AAPLAction *> *)secondaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath;

/// Called when a data source becomes active in a collection view. If the data source is in the `AAPLLoadStateInitial` state, it will be sent a `-loadContent` message.
- (void)didBecomeActive NS_REQUIRES_SUPER;

/// Called when a data source becomes inactive in a collection view
- (void)willResignActive NS_REQUIRES_SUPER;

/// Should this data source allow its items to be selected? The default value is YES.
@property (nonatomic) BOOL allowsSelection;

#pragma mark - Notifications

/// Update the state of the data source in a safe manner. This ensures the collection view will be updated appropriately.
- (void)performUpdate:(dispatch_block_t)update complete:(nullable dispatch_block_t)complete;

/// Update the state of the data source in a safe manner. This ensures the collection view will be updated appropriately.
- (void)performUpdate:(dispatch_block_t)update;

/// Notify the parent data source and the collection view that new items have been inserted at positions represented by insertedIndexPaths.
- (void)notifyItemsInsertedAtIndexPaths:(NSArray<NSIndexPath *> *)insertedIndexPaths;
/// Notify the parent data source and collection view that the items represented by removedIndexPaths have been removed from this data source.
- (void)notifyItemsRemovedAtIndexPaths:(NSArray<NSIndexPath *> *)removedIndexPaths;
/// Notify the parent data sources and collection view that the items represented by refreshedIndexPaths have been updated and need redrawing.
- (void)notifyItemsRefreshedAtIndexPaths:(NSArray<NSIndexPath *> *)refreshedIndexPaths;
/// Alert parent data sources and the collection view that the item at indexPath was moved to newIndexPath.
- (void)notifyItemMovedFromIndexPath:(NSIndexPath *)indexPath toIndexPaths:(NSIndexPath *)newIndexPath;

/// Notify parent data sources and the collection view that the sections were inserted.
- (void)notifySectionsInserted:(NSIndexSet *)sections;
/// Notify parent data sources and (eventually) the collection view that the sections were removed.
- (void)notifySectionsRemoved:(NSIndexSet *)sections;
/// Notify parent data sources and the collection view that the section at oldSectionIndex was moved to newSectionIndex.
- (void)notifySectionMovedFrom:(NSInteger)oldSectionIndex to:(NSInteger)newSectionIndex;
/// Notify parent data sources and ultimately the collection view the specified sections were refreshed.
- (void)notifySectionsRefreshed:(NSIndexSet *)sections;

/// Notify parent data sources and ultimately the collection view that the data in this data source has been reloaded.
- (void)notifyDidReloadData;

/// Update the supplementary view or views associated with the header's AAPLSupplementaryItem and invalidate the layout
- (void)notifyContentUpdatedForHeader:(AAPLSupplementaryItem *)header;
/// Update the supplementary view or views associated with the footer's AAPLSupplementaryItem and invalidate the layout
- (void)notifyContentUpdatedForFooter:(AAPLSupplementaryItem *)footer;

#pragma mark - Metrics

/// The default metrics for all sections in this data source.
@property (nonatomic, strong) AAPLSectionMetrics *defaultMetrics;
/// The metrics for the global section (headers and footers) for this data source. This is only meaningful when this is the root or top-level data source.
@property (nonatomic, strong) AAPLSectionMetrics *globalMetrics;

/// Retrieve the layout metrics for a specific section within this data source.
- (nullable AAPLSectionMetrics *)metricsForSectionAtIndex:(NSInteger)sectionIndex;
/// Store customised layout metrics for a section in this data source. The values specified in metrics will override values specified by the data source's defaultMetrics.
- (void)setMetrics:(AAPLSectionMetrics *)metrics forSectionAtIndex:(NSInteger)sectionIndex;

/// Look up a data source header by its key. These headers will appear before headers from section 0. Returns nil when the header with the given key can not be found.
- (nullable AAPLSupplementaryItem *)headerForKey:(NSString *)key;
/// Create a new header and append it to the collection of data source headers.
- (AAPLSupplementaryItem *)newHeaderForKey:(NSString *)key;
/// Remove a data source header specified by its key.
- (void)removeHeaderForKey:(NSString *)key;
/// Replace a data source header specified by its key with a new header with the same key.
- (void)replaceHeaderForKey:(NSString *)key withHeader:(AAPLSupplementaryItem *)header;

/** Create a header for each section in this data source.

 @note The configuration block for this header will be called once for each section in the data source.
 */
- (AAPLSupplementaryItem *)newSectionHeader;

/** Create a footer for each section in this data source.

 @note Like -newSectionHeader, the configuration block for this footer will be called once for each section in the data source.
 */
- (AAPLSupplementaryItem *)newSectionFooter;

/// Create a new header for a specific section. This header will only appear in the given section.
- (AAPLSupplementaryItem *)newHeaderForSectionAtIndex:(NSInteger)sectionIndex;
/// Create a new footer for a specific section. This footer will only appear in the given section.
- (AAPLSupplementaryItem *)newFooterForSectionAtIndex:(NSInteger)sectionIndex;

#pragma mark - Placeholders

/// The placeholder to show when the data source is in the No Content state.
@property (nullable, nonatomic, copy) AAPLDataSourcePlaceholder *noContentPlaceholder;

/// The placeholder to show when the data source is in the Error state.
@property (nullable, nonatomic, copy) AAPLDataSourcePlaceholder *errorPlaceholder;

#pragma mark - Subclass hooks

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

#pragma mark - Content loading

/// Signal that the datasource should reload its content
- (void)setNeedsLoadContent;

/// Reset the content and loading state.
- (void)resetContent NS_REQUIRES_SUPER;

/// Use this method to wait for content to load. The block will be called once the loadingState has transitioned to the ContentLoaded, NoContent, or Error states. If the data source is already in that state, the block will be called immediately.
- (void)whenLoaded:(dispatch_block_t)block;

@end


#if DEBUG
extern BOOL AAPLInDataSourceUpdate(AAPLDataSource *dataSource);
/// Assertion for ensuring that the executing code is operating within an update block.
#define AAPL_ASSERT_IN_DATASOURCE_UPDATE() NSAssert(AAPLInDataSourceUpdate(self), @"%@ expected to be called within update block", NSStringFromSelector(_cmd));
#else
#define AAPL_ASSERT_IN_DATASOURCE_UPDATE()
#endif




NS_ASSUME_NONNULL_END
