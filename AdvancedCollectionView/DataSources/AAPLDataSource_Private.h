/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The base data source class.
  
  This file contains methods used internally by subclasses. These methods are not considered part of the public API of AAPLDataSource. It is possible to implement fully functional data sources without using these methods.
  
 */

#import "AAPLDataSource.h"

@protocol AAPLDataSourceDelegate;
@class AAPLCollectionPlaceholderView;

typedef enum {
    AAPLDataSourceSectionOperationDirectionNone = 0,
    AAPLDataSourceSectionOperationDirectionLeft,
    AAPLDataSourceSectionOperationDirectionRight,
} AAPLDataSourceSectionOperationDirection;



@interface AAPLDataSource ()
- (AAPLCollectionPlaceholderView *)dequeuePlaceholderViewForCollectionView:(UICollectionView *)collectionView atIndexPath:(NSIndexPath *)indexPath;

- (AAPLLayoutSectionMetrics *)snapshotMetricsForSectionAtIndex:(NSInteger)sectionIndex;

- (void)updatePlaceholder:(AAPLCollectionPlaceholderView *)placeholderView notifyVisibility:(BOOL)notify;

- (void)stateWillChange;
- (void)stateDidChange;

- (void)enqueuePendingUpdateBlock:(dispatch_block_t)block;
- (void)executePendingUpdates;

- (NSIndexPath *)localIndexPathForGlobalIndexPath:(NSIndexPath *)globalIndexPath;

/// Is this data source the root data source? This depends on proper set up of the delegate property. Container data sources ALWAYS act as the delegate for their contained data sources.
@property (nonatomic, readonly, getter = isRootDataSource) BOOL rootDataSource;

/// Whether this data source should display the placeholder.
@property (nonatomic, readonly) BOOL shouldDisplayPlaceholder;

/// A delegate object that will receive change notifications from this data source.
@property (nonatomic, weak) id<AAPLDataSourceDelegate> delegate;

- (void)notifySectionsInserted:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)notifySectionsRemoved:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)notifySectionMovedFrom:(NSInteger)section to:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction;

@end

@protocol AAPLDataSourceDelegate <NSObject>
@optional

- (void)dataSource:(AAPLDataSource *)dataSource didInsertItemsAtIndexPaths:(NSArray *)indexPaths;
- (void)dataSource:(AAPLDataSource *)dataSource didRemoveItemsAtIndexPaths:(NSArray *)indexPaths;
- (void)dataSource:(AAPLDataSource *)dataSource didRefreshItemsAtIndexPaths:(NSArray *)indexPaths;
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
@end
