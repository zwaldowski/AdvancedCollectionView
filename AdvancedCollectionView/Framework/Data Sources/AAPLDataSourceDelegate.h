//
//  AAPLDataSourceHeader.h
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 7/12/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "AAPLDataSource.h"

@class AAPLCollectionPlaceholderView;

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
- (void)dataSource:(AAPLDataSource *)dataSource performBatchUpdate:(void(^)(void))update completion:(void(^)(BOOL finished))completion;

/// If the content was loaded successfully, the error will be nil.
- (void)dataSource:(AAPLDataSource *)dataSource didLoadContentWithError:(NSError *)error;

/// Called just before a data source begins loading its content.
- (void)dataSourceWillLoadContent:(AAPLDataSource *)dataSource;
@end

@interface AAPLDataSource ()

/// A delegate object that will receive change notifications from this data source.
@property (nonatomic, weak) id<AAPLDataSourceDelegate> delegate;

@end