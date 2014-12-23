/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLCollectionViewController.h"
#import "AAPLDataSource_Private.h"
#import "AAPLCollectionViewGridLayout_Private.h"

#define UPDATE_DEBUGGING 0

static void * const AAPLDataSourceContext = @"DataSourceContext";

@interface AAPLCollectionViewController () <UICollectionViewDelegate, AAPLDataSourceDelegate>
@end

@implementation AAPLCollectionViewController

- (void)dealloc
{
    [self.collectionView removeObserver:self forKeyPath:@"dataSource" context:AAPLDataSourceContext];
}

- (void)loadView
{
    [super loadView];
    //  We need to know when the data source changes on the collection view so we can become the delegate for any APPLDataSource subclasses.
    [self.collectionView addObserver:self forKeyPath:@"dataSource" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:AAPLDataSourceContext];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    UICollectionView *collectionView = self.collectionView;

    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if ([dataSource isKindOfClass:[AAPLDataSource class]]) {
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
    if (AAPLDataSourceContext != context) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    UICollectionView *collectionView = object;
    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;

    if ([dataSource isKindOfClass:[AAPLDataSource class]]) {
        AAPLDataSource *aaplDataSource = (AAPLDataSource *)dataSource;
        if (!aaplDataSource.delegate)
            aaplDataSource.delegate = self;
    }
}

#pragma mark - UICollectionViewDelegate methods

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark - AAPLDataSourceDelegate methods

#if UPDATE_DEBUGGING

- (NSString *)stringFromIndexSet:(NSIndexSet *)indexSet
{
    NSMutableString *result = [NSMutableString string];
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if ([result length])
            [result appendString:@", "];
        [result appendFormat:@"%u", idx];
    }];

    return result;
}

- (NSString *)stringFromIndexPath:(NSIndexPath *)indexPath
{
    return [NSString stringWithFormat:@"{%d, %d}", indexPath.section, indexPath.item];
}

- (NSString *)stringFromArrayOfIndexPaths:(NSArray *)indexPaths
{
    NSMutableString *result = [NSMutableString string];
    for (NSIndexPath *indexPath in indexPaths) {
        if ([result length])
            [result appendString:@", "];
        [result appendString:[self stringFromIndexPath:indexPath]];
    }
    return result;
}

#endif

- (void)dataSource:(AAPLDataSource *)dataSource didInsertItemsAtIndexPaths:(NSArray *)indexPaths
{
#if UPDATE_DEBUGGING
    NSLog(@"INSERT ITEMS: %@", [self stringFromArrayOfIndexPaths:indexPaths]);
#endif
    [self.collectionView insertItemsAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveItemsAtIndexPaths:(NSArray *)indexPaths
{
#if UPDATE_DEBUGGING
    NSLog(@"REMOVE ITEMS: %@", [self stringFromArrayOfIndexPaths:indexPaths]);
#endif

    [self.collectionView deleteItemsAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshItemsAtIndexPaths:(NSArray *)indexPaths
{
#if UPDATE_DEBUGGING
    NSLog(@"REFRESH ITEMS: %@", [self stringFromArrayOfIndexPaths:indexPaths]);
#endif

    [self.collectionView reloadItemsAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didInsertSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    if (!sections)  // bail if nil just to keep collection view safe and pure
        return;
#if UPDATE_DEBUGGING
    NSLog(@"INSERT SECTIONS: %@", [self stringFromIndexSet:sections]);
#endif
    AAPLCollectionViewGridLayout *layout = (AAPLCollectionViewGridLayout *)self.collectionView.collectionViewLayout;
    if ([layout isKindOfClass:[AAPLCollectionViewGridLayout class]])
        [layout dataSource:dataSource didInsertSections:sections direction:direction];
    [self.collectionView insertSections:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    if (!sections)  // bail if nil just to keep collection view safe and pure
        return;

#if UPDATE_DEBUGGING
    NSLog(@"DELETE SECTIONS: %@", [self stringFromIndexSet:sections]);
#endif
    AAPLCollectionViewGridLayout *layout = (AAPLCollectionViewGridLayout *)self.collectionView.collectionViewLayout;
    if ([layout isKindOfClass:[AAPLCollectionViewGridLayout class]])
        [layout dataSource:dataSource didRemoveSections:sections direction:direction];
    [self.collectionView deleteSections:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveSection:(NSInteger)section toSection:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction
{
#if UPDATE_DEBUGGING
    NSLog(@"MOVE SECTION: %d TO: %d", section, newSection);
#endif
    AAPLCollectionViewGridLayout *layout = (AAPLCollectionViewGridLayout *)self.collectionView.collectionViewLayout;
    if ([layout isKindOfClass:[AAPLCollectionViewGridLayout class]])
        [layout dataSource:dataSource didMoveSection:section toSection:newSection direction:direction];
    [self.collectionView moveSection:section toSection:newSection];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
#if UPDATE_DEBUGGING
    NSLog(@"MOVE ITEM: %@ TO: %@", [self stringFromIndexPath:indexPath], [self stringFromIndexPath:newIndexPath]);
#endif
    [self.collectionView moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshSections:(NSIndexSet *)sections
{
    if (!sections)  // bail if nil just to keep collection view safe and pure
        return;
#if UPDATE_DEBUGGING
    NSLog(@"REFRESH SECTIONS: %@", [self stringFromIndexSet:sections]);
#endif
    [self.collectionView reloadSections:sections];
}

- (void)dataSourceDidReloadData:(AAPLDataSource *)dataSource
{
#if UPDATE_DEBUGGING
    NSLog(@"RELOAD");
#endif
    [self.collectionView reloadData];
}

- (void)dataSourceDidReloadGlobalSection:(AAPLDataSource *)dataSource
{
#if UPDATE_DEBUGGING
    NSLog(@"RELOAD GLOBAL SECTION");
#endif
    AAPLCollectionViewGridLayout *layout = (id)self.collectionViewLayout;
    if (![layout isKindOfClass:AAPLCollectionViewGridLayout.class]) {
        [self.collectionView reloadData];
        return;
    }
    [layout invalidateLayoutForGlobalSection];
}

- (void)dataSource:(AAPLDataSource *)dataSource performBatchUpdate:(dispatch_block_t)update complete:(dispatch_block_t)complete
{
    [self.collectionView performBatchUpdates:^{
        update();
    } completion:^(BOOL finished){
        if (complete) {
            complete();
        }
        [self.collectionView reloadData];
    }];
}

@end
