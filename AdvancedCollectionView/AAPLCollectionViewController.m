/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of UICollectionViewController that adds support for swipe to edit and drag reordering.
  
 */

#import "AAPLCollectionViewController.h"
#import "AAPLDataSource_Private.h"
#import "AAPLSwipeToEditStateMachine.h"
#import "AAPLCollectionViewGridLayout_Private.h"
#import "AAPLCollectionViewCell.h"

#define UPDATE_DEBUGGING 0

static void * const AAPLDataSourceContext = @"DataSourceContext";

@interface AAPLCollectionViewController () <UICollectionViewDelegate, AAPLDataSourceDelegate>
@property (nonatomic, strong) AAPLSwipeToEditStateMachine *swipeStateMachine;
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
    _swipeStateMachine = [[AAPLSwipeToEditStateMachine alloc] initWithCollectionView:self.collectionView];
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

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.editing = NO;
    [_swipeStateMachine viewDidDisappear:animated];
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

- (void)setEditing:(BOOL)editing
{
    if (_editing == editing)
        return;

    _editing = editing;

    AAPLCollectionViewGridLayout *layout = (AAPLCollectionViewGridLayout *)self.collectionView.collectionViewLayout;

    NSAssert([layout isKindOfClass:[AAPLCollectionViewGridLayout class]], @"Editing only supported when using a layout derived from AAPLCollectionViewGridLayout");

    if ([layout isKindOfClass:[AAPLCollectionViewGridLayout class]])
        layout.editing = editing;
    self.swipeStateMachine.batchEditing = editing;
    [layout invalidateLayout];
}

#pragma mark - Swipe to delete support

- (void)shutActionPaneAnimated:(BOOL)animated
{
    [self.swipeStateMachine shutActionPaneForEditingCellAnimated:animated];
}

- (void)swipeToDeleteCell:(AAPLCollectionViewCell *)sender
{
    UICollectionView *collectionView = self.collectionView;
    AAPLCollectionViewGridLayout *layout = (AAPLCollectionViewGridLayout *)collectionView.collectionViewLayout;
    if (![layout isKindOfClass:[AAPLCollectionViewGridLayout class]])
        return;

    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        return;

    NSIndexPath *deleteIndexPath = [self.collectionView indexPathForCell:sender];
    [dataSource removeItemAtIndexPath:deleteIndexPath];
}

- (void)willDismissActionSheetFromCell:(UICollectionViewCell *)cell
{
    [_swipeStateMachine shutActionPaneForEditingCellAnimated:YES];
}

#pragma mark - UICollectionViewDelegate methods

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_swipeStateMachine.currentState isEqualToString:AAPLSwipeStateNothing];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.editing)
        return NO;
    else
        return YES;
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
    NSIndexPath *trackedIndexPath = _swipeStateMachine.trackedIndexPath;
    if (trackedIndexPath) {
        for (NSIndexPath *indexPath in indexPaths) {
            if ([trackedIndexPath isEqual:indexPath]) {
                [_swipeStateMachine shutActionPaneForEditingCellAnimated:NO];
                break;
            }
        }
    }

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

    NSIndexPath *trackedIndexPath = _swipeStateMachine.trackedIndexPath;
    if (trackedIndexPath) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger sectionIndex, BOOL *stop) {
            if (trackedIndexPath.section  == sectionIndex) {
                [_swipeStateMachine shutActionPaneForEditingCellAnimated:NO];
                *stop = YES;
            }
        }];
    }

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
