/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of AAPLDataSource with multiple child data sources, however, only one data source will be visible at a time. Load content messages will be sent only to the selected data source. When selected, if a data source is still in the initial state, it will receive a load content message.
  
 */

#import "AAPLDataSource_Private.h"
#import "AAPLSegmentedDataSource.h"
#import "AAPLLayoutMetrics.h"
#import "AAPLSegmentedHeaderView.h"

NSString * const AAPLSegmentedDataSourceHeaderKey = @"AAPLSegmentedDataSourceHeaderKey";

@interface AAPLSegmentedDataSource () <AAPLDataSourceDelegate>
@property (nonatomic, strong) NSMutableArray *mutableDataSources;
@end

@implementation AAPLSegmentedDataSource
@synthesize mutableDataSources = _dataSources;

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _dataSources = [NSMutableArray array];
    _shouldDisplayDefaultHeader = YES;

    return self;
}

- (NSInteger)numberOfSections
{
    return _selectedDataSource.numberOfSections;
}

- (AAPLDataSource *)dataSourceForSectionAtIndex:(NSInteger)sectionIndex
{
    return [_selectedDataSource dataSourceForSectionAtIndex:sectionIndex];
}

- (NSIndexPath *)localIndexPathForGlobalIndexPath:(NSIndexPath *)globalIndexPath
{
    return [_selectedDataSource localIndexPathForGlobalIndexPath:globalIndexPath];
}

- (NSArray *)dataSources
{
    return [NSArray arrayWithArray:_dataSources];
}

- (void)addDataSource:(AAPLDataSource *)dataSource
{
    if (![_dataSources count])
        _selectedDataSource = dataSource;
    [_dataSources addObject:dataSource];
    dataSource.delegate = self;
}

- (void)removeDataSource:(AAPLDataSource *)dataSource
{
    [_dataSources removeObject:dataSource];
    if (dataSource.delegate == self)
        dataSource.delegate = nil;
}

- (void)removeAllDataSources
{
    for (AAPLDataSource *dataSource in _dataSources) {
        if (dataSource.delegate == self)
            dataSource.delegate = nil;
    }

    _dataSources = [NSMutableArray array];
    _selectedDataSource = nil;
}

- (AAPLDataSource *)dataSourceAtIndex:(NSInteger)dataSourceIndex
{
    return _dataSources[dataSourceIndex];
}

- (NSInteger)selectedDataSourceIndex
{
    return [_dataSources indexOfObject:_selectedDataSource];
}

- (void)setSelectedDataSourceIndex:(NSInteger)selectedDataSourceIndex
{
    [self setSelectedDataSourceIndex:selectedDataSourceIndex animated:NO];
}

- (void)setSelectedDataSourceIndex:(NSInteger)selectedDataSourceIndex animated:(BOOL)animated
{
    AAPLDataSource *dataSource = [_dataSources objectAtIndex:selectedDataSourceIndex];
    [self setSelectedDataSource:dataSource animated:animated completionHandler:nil];
}

- (void)setSelectedDataSource:(AAPLDataSource *)selectedDataSource
{
    [self setSelectedDataSource:selectedDataSource animated:NO completionHandler:nil];
}

- (void)setSelectedDataSource:(AAPLDataSource *)selectedDataSource animated:(BOOL)animated
{
    [self setSelectedDataSource:selectedDataSource animated:animated completionHandler:nil];
}

- (void)setSelectedDataSource:(AAPLDataSource *)selectedDataSource animated:(BOOL)animated completionHandler:(dispatch_block_t)handler
{
    if (_selectedDataSource == selectedDataSource) {
        if (handler)
            handler();
        return;
    }

    [self willChangeValueForKey:@"selectedDataSource"];
    [self willChangeValueForKey:@"selectedDataSourceIndex"];
    NSAssert([_dataSources containsObject:selectedDataSource], @"selected data source must be contained in this data source");

    AAPLDataSource *oldDataSource = _selectedDataSource;
    NSInteger numberOfOldSections = oldDataSource.numberOfSections;
    NSInteger numberOfNewSections = selectedDataSource.numberOfSections;

    AAPLDataSourceSectionOperationDirection direction = AAPLDataSourceSectionOperationDirectionNone;

    if (animated) {
        NSInteger oldIndex = [_dataSources indexOfObjectIdenticalTo:oldDataSource];
        NSInteger newIndex = [_dataSources indexOfObjectIdenticalTo:selectedDataSource];
        direction = (oldIndex < newIndex) ? AAPLDataSourceSectionOperationDirectionRight : AAPLDataSourceSectionOperationDirectionLeft;
    }

    NSIndexSet *removedSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, numberOfOldSections)];;
    NSIndexSet *insertedSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, numberOfNewSections)];

    _selectedDataSource = selectedDataSource;

    [self didChangeValueForKey:@"selectedDataSource"];
    [self didChangeValueForKey:@"selectedDataSourceIndex"];

    // Update the sections all at once.
    [self notifyBatchUpdate:^{
        if (removedSet)
            [self notifySectionsRemoved:removedSet direction:direction];
        if (insertedSet)
            [self notifySectionsInserted:insertedSet direction:direction];
    } complete:handler];

    // If the newly selected data source has never been loaded, load it now
    if ([selectedDataSource.loadingState isEqualToString:AAPLLoadStateInitial])
        [selectedDataSource setNeedsLoadContent];

}

- (NSArray *)indexPathsForItem:(id)object
{
    return [_selectedDataSource indexPathsForItem:object];
}

- (id)itemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_selectedDataSource itemAtIndexPath:indexPath];
}

- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath
{
    [_selectedDataSource removeItemAtIndexPath:indexPath];
}

- (void)configureSegmentedControl:(UISegmentedControl *)segmentedControl
{
    NSArray *titles = [self.dataSources valueForKey:@"title"];

    [segmentedControl removeAllSegments];
    [titles enumerateObjectsUsingBlock:^(NSString *segmentTitle, NSUInteger segmentIndex, BOOL *stop) {
        if ([segmentTitle isEqual:[NSNull null]])
            segmentTitle = @"NULL";
        [segmentedControl insertSegmentWithTitle:segmentTitle atIndex:segmentIndex animated:NO];
    }];
    [segmentedControl addTarget:self action:@selector(selectedSegmentIndexChanged:) forControlEvents:UIControlEventValueChanged];
    segmentedControl.selectedSegmentIndex = self.selectedDataSourceIndex;
}

- (AAPLLayoutSupplementaryMetrics *)segmentedControlHeader
{
    if (!self.shouldDisplayDefaultHeader)
        return nil;

    AAPLLayoutSupplementaryMetrics *defaultHeader = [self headerForKey:AAPLSegmentedDataSourceHeaderKey];
    if (defaultHeader)
        return defaultHeader;

    AAPLLayoutSupplementaryMetrics *header = [self newHeaderForKey:AAPLSegmentedDataSourceHeaderKey];
    header.supplementaryViewClass = [AAPLSegmentedHeaderView class];
    header.shouldPin = YES;
    // Show this header regardless of whether there are items
    header.visibleWhileShowingPlaceholder = YES;
    header.configureView = ^(UICollectionReusableView *headerView, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        AAPLSegmentedHeaderView *segmentedHeaderView = (AAPLSegmentedHeaderView *)headerView;
        AAPLSegmentedDataSource *segmentedDataSource = (AAPLSegmentedDataSource *)dataSource;
        [segmentedDataSource configureSegmentedControl:segmentedHeaderView.segmentedControl];
    };

    return header;
}

- (AAPLLayoutSectionMetrics *)snapshotMetricsForSectionAtIndex:(NSInteger)sectionIndex
{
    AAPLLayoutSupplementaryMetrics *defaultHeader = [self headerForKey:AAPLSegmentedDataSourceHeaderKey];
    if (self.shouldDisplayDefaultHeader) {
        if (!defaultHeader)
            [self segmentedControlHeader];
    }
    else {
        if (defaultHeader)
            [self removeHeaderForKey:AAPLSegmentedDataSourceHeaderKey];
    }


    AAPLLayoutSectionMetrics *metrics = [_selectedDataSource snapshotMetricsForSectionAtIndex:sectionIndex];
    AAPLLayoutSectionMetrics *enclosingMetrics = [super snapshotMetricsForSectionAtIndex:sectionIndex];

    [enclosingMetrics applyValuesFromMetrics:metrics];
    return enclosingMetrics;
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];

    for (AAPLDataSource *dataSource in self.dataSources)
        [dataSource registerReusableViewsWithCollectionView:collectionView];
}

- (CGSize)collectionView:(UICollectionView *)collectionView sizeFittingSize:(CGSize)size forItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_selectedDataSource collectionView:collectionView sizeFittingSize:size forItemAtIndexPath:indexPath];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canEditItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_selectedDataSource collectionView:collectionView canEditItemAtIndexPath:indexPath];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_selectedDataSource collectionView:collectionView canMoveItemAtIndexPath:indexPath];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    return [_selectedDataSource collectionView:collectionView canMoveItemAtIndexPath:indexPath toIndexPath:destinationIndexPath];
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    [_selectedDataSource collectionView:collectionView moveItemAtIndexPath:indexPath toIndexPath:destinationIndexPath];
}


#pragma mark - AAPLContentLoading

- (void)loadContent
{
    // Only load the currently selected data source. Others will be loaded as necessary.
    [_selectedDataSource loadContent];
}

- (void)resetContent
{
    for (AAPLDataSource *dataSource in self.dataSources)
         [dataSource resetContent];
    [super resetContent];
}

#pragma mark - Placeholders

- (BOOL)shouldDisplayPlaceholder
{
    if ([super shouldDisplayPlaceholder])
        return YES;

    NSString *loadingState = _selectedDataSource.loadingState;

    // If we're in the error state & have an error message or title
    if ([loadingState isEqualToString:AAPLLoadStateError] && (_selectedDataSource.errorMessage || _selectedDataSource.errorTitle))
        return YES;

    // Only display a placeholder when we're loading or have no content
    if (![loadingState isEqualToString:AAPLLoadStateLoadingContent] && ![loadingState isEqualToString:AAPLLoadStateNoContent])
        return NO;

    // Can't display the placeholder if both the title and message is missing
    if (!_selectedDataSource.noContentMessage && !_selectedDataSource.noContentTitle)
        return NO;

    return YES;
}

//- (AAPLCollectionPlaceholderView *)dequeuePlaceholderViewForCollectionView:(UICollectionView *)collectionView atIndexPath:(NSIndexPath *)indexPath
//{
//    return [_selectedDataSource dequeuePlaceholderViewForCollectionView:collectionView atIndexPath:indexPath];
//}

- (void)updatePlaceholder:(AAPLCollectionPlaceholderView *)placeholderView notifyVisibility:(BOOL)notify
{
    [_selectedDataSource updatePlaceholder:placeholderView notifyVisibility:notify];
}

- (NSString *)noContentMessage
{
    return _selectedDataSource.noContentMessage;
}

- (NSString *)noContentTitle
{
    return _selectedDataSource.noContentTitle;
}

- (UIImage *)noContentImage
{
    return _selectedDataSource.noContentImage;
}

- (NSString *)errorTitle
{
    return _selectedDataSource.errorTitle;
}

- (NSString *)errorMessage
{
    return _selectedDataSource.errorMessage;
}

- (UIImage *)errorImage
{
    return _selectedDataSource.errorImage;
}

#pragma mark - Header action method

- (void)selectedSegmentIndexChanged:(id)sender
{
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    if (![segmentedControl isKindOfClass:[UISegmentedControl class]])
          return;

    segmentedControl.userInteractionEnabled = NO;
    NSInteger selectedSegmentIndex = segmentedControl.selectedSegmentIndex;
    AAPLDataSource *dataSource = self.dataSources[selectedSegmentIndex];
    [self setSelectedDataSource:dataSource animated:YES completionHandler:^{
        segmentedControl.userInteractionEnabled = YES;
    }];
}

#pragma mark - UICollectionViewDataSource methods

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.shouldDisplayPlaceholder)
        return 0;

    return [_selectedDataSource collectionView:collectionView numberOfItemsInSection:section];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_selectedDataSource collectionView:collectionView cellForItemAtIndexPath:indexPath];
}

//- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
//{
//    return [_selectedDataSource collectionView:collectionView viewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
//}

#pragma mark - AAPLDataSourceDelegate methods

- (void)dataSource:(AAPLDataSource *)dataSource didInsertItemsAtIndexPaths:(NSArray *)indexPaths
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifyItemsInsertedAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveItemsAtIndexPaths:(NSArray *)indexPaths
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifyItemsRemovedAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshItemsAtIndexPaths:(NSArray *)indexPaths
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifyItemsRefreshedAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveItemAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifyItemMovedFromIndexPath:fromIndexPath toIndexPaths:newIndexPath];
}

- (void)dataSource:(AAPLDataSource *)dataSource didInsertSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifySectionsInserted:sections direction:direction];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifySectionsRemoved:sections direction:direction];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshSections:(NSIndexSet *)sections
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifySectionsRefreshed:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveSection:(NSInteger)section toSection:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifySectionMovedFrom:section to:newSection direction:direction];
}

- (void)dataSourceDidReloadData:(AAPLDataSource *)dataSource
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifyDidReloadData];
}

- (void)dataSource:(AAPLDataSource *)dataSource performBatchUpdate:(dispatch_block_t)update complete:(dispatch_block_t)complete
{
    if (dataSource != _selectedDataSource) {
        if (update)
            update();
        if (complete)
            complete();
        return;
    }

    [self notifyBatchUpdate:update complete:complete];
}

- (void)dataSource:(AAPLDataSource *)dataSource didLoadContentWithError:(NSError *)error
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifyContentLoadedWithError:error];
}

- (void)dataSourceWillLoadContent:(AAPLDataSource *)dataSource
{
    if (dataSource != _selectedDataSource)
        return;

    [self notifyWillLoadContent];
}

@end
