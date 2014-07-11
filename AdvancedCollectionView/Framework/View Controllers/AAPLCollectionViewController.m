/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLCollectionViewController.h"
#import "AAPLDataSource_Private.h"

static void *AAPLDataSourceContext = &AAPLDataSourceContext;

@interface AAPLCollectionViewController () <UICollectionViewDelegate, AAPLDataSourceDelegate>

@end

@implementation AAPLCollectionViewController

- (void)loadView
{
    [super loadView];
    //  We need to know when the data source changes on the collection view so we can become the delegate for any APPLDataSource subclasses.
    [self.collectionView addObserver:self forKeyPath:@"dataSource" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:AAPLDataSourceContext];
}

- (void)dealloc
{
	[self.collectionView removeObserver:self forKeyPath:@"dataSource" context:AAPLDataSourceContext];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    UICollectionView *collectionView = self.collectionView;

    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if ([dataSource isKindOfClass:AAPLDataSource.class]) {
        [dataSource registerReusableViewsWithCollectionView:collectionView];
        [dataSource setNeedsLoadContent];
    }
}

- (void)setCollectionView:(UICollectionView *)collectionView
{
    UICollectionView *oldCollectionView = self.collectionView;

    // Always call super, because we don't know EXACTLY what UICollectionViewController does in -setCollectionView:.
    [super setCollectionView:collectionView];

    [oldCollectionView removeObserver:self forKeyPath:@"dataSource" context:AAPLDataSourceContext];

    //  We need to know when the data source changes on the collection view so we can become the delegate for any APPLDataSource subclasses.
    [collectionView addObserver:self forKeyPath:@"dataSource" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:AAPLDataSourceContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    //  For change contexts that aren't the data source, pass them to super.
	if (context == AAPLDataSourceContext) {
		UICollectionView *collectionView = object;
		AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
		if ([dataSource isKindOfClass:AAPLDataSource.class]) {
			if (!dataSource.delegate)
				dataSource.delegate = self;
		}
		
		return;
	}
	
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - AAPLDataSourceDelegate methods

- (void)dataSource:(AAPLDataSource *)dataSource didInsertItemsAtIndexPaths:(NSArray *)indexPaths
{
    [self.collectionView insertItemsAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveItemsAtIndexPaths:(NSArray *)indexPaths
{
    [self.collectionView deleteItemsAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshItemsAtIndexPaths:(NSArray *)indexPaths
{
    [self.collectionView reloadItemsAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didInsertSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    if (!sections)  // bail if nil just to keep collection view safe and pure
        return;

	id <AAPLDataSourceDelegate> layout = (id <AAPLDataSourceDelegate>)self.collectionView.collectionViewLayout;
	if ([layout conformsToProtocol:@protocol(AAPLDataSourceDelegate)] && [layout respondsToSelector:@selector(dataSource:didInsertSections:direction:)]) {
		[layout dataSource:dataSource didInsertSections:sections direction:direction];
	}
    [self.collectionView insertSections:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    if (!sections)  // bail if nil just to keep collection view safe and pure
        return;

	id <AAPLDataSourceDelegate> layout = (id <AAPLDataSourceDelegate>)self.collectionView.collectionViewLayout;
	if ([layout conformsToProtocol:@protocol(AAPLDataSourceDelegate)] && [layout respondsToSelector:@selector(dataSource:didRemoveSections:direction:)]) {
		[layout dataSource:dataSource didRemoveSections:sections direction:direction];
	}
    [self.collectionView deleteSections:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveSection:(NSInteger)section toSection:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction
{
	id <AAPLDataSourceDelegate> layout = (id <AAPLDataSourceDelegate>)self.collectionView.collectionViewLayout;
	if ([layout conformsToProtocol:@protocol(AAPLDataSourceDelegate)] && [layout respondsToSelector:@selector(dataSource:didMoveSection:toSection:direction:)]) {
		[layout dataSource:dataSource didMoveSection:section toSection:newSection direction:direction];
	}
    [self.collectionView moveSection:section toSection:newSection];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    [self.collectionView moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshSections:(NSIndexSet *)sections
{
    if (!sections)  // bail if nil just to keep collection view safe and pure
        return;

	[self.collectionView reloadSections:sections];
}

- (void)dataSourceDidReloadData:(AAPLDataSource *)dataSource
{
    [self.collectionView reloadData];
}

- (void)dataSource:(AAPLDataSource *)dataSource performBatchUpdate:(dispatch_block_t)update complete:(dispatch_block_t)complete
{
    [self.collectionView performBatchUpdates:update completion:^(BOOL finished){
        if (complete) {
            complete();
        }
        [self.collectionView reloadData];
    }];
}

@end
