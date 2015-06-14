/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
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
    AAPLDataSource *dataSource = _dataSources[selectedDataSourceIndex];
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

    // Update the sections all at once.
    [self performUpdate:^{
        [oldDataSource willResignActive];

        if (removedSet)
            [self notifySectionsRemoved:removedSet direction:direction];

        [self willChangeValueForKey:@"selectedDataSource"];
        [self willChangeValueForKey:@"selectedDataSourceIndex"];

        _selectedDataSource = selectedDataSource;

        [self didChangeValueForKey:@"selectedDataSource"];
        [self didChangeValueForKey:@"selectedDataSourceIndex"];

        if (insertedSet)
            [self notifySectionsInserted:insertedSet direction:direction];

        [selectedDataSource didBecomeActive];
    } complete:handler];

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

- (NSArray *)primaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_selectedDataSource primaryActionsForItemAtIndexPath:indexPath];
}

- (NSArray *)secondaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_selectedDataSource secondaryActionsForItemAtIndexPath:indexPath];
}

- (void)didBecomeActive
{
    [super didBecomeActive];
    [_selectedDataSource didBecomeActive];
}

- (void)willResignActive
{
    [super willResignActive];
    [_selectedDataSource willResignActive];
}

- (BOOL)allowsSelection
{
    return [_selectedDataSource allowsSelection];
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

- (AAPLSupplementaryItem *)segmentedControlHeader
{
    if (!self.shouldDisplayDefaultHeader)
        return nil;

    AAPLSupplementaryItem *defaultHeader = [self headerForKey:AAPLSegmentedDataSourceHeaderKey];
    if (defaultHeader)
        return defaultHeader;

    AAPLSupplementaryItem *header = [self newHeaderForKey:AAPLSegmentedDataSourceHeaderKey];
    header.supplementaryViewClass = [AAPLSegmentedHeaderView class];
    header.shouldPin = YES;
    header.showsSeparator = YES;
    // Show this header regardless of whether there are items
    header.visibleWhileShowingPlaceholder = YES;
    header.configureView = ^(AAPLSegmentedHeaderView *headerView, AAPLSegmentedDataSource *dataSource, NSIndexPath *indexPath) {
        [dataSource configureSegmentedControl:headerView.segmentedControl];
    };

    return header;
}

- (NSInteger)numberOfHeadersInSectionAtIndex:(NSInteger)sectionIndex includeChildDataSouces:(BOOL)includeChildDataSources
{
    NSInteger numberOfHeaders = [super numberOfHeadersInSectionAtIndex:sectionIndex includeChildDataSouces:NO];
    if (includeChildDataSources)
        numberOfHeaders += [_selectedDataSource numberOfHeadersInSectionAtIndex:sectionIndex includeChildDataSouces:YES];
    return numberOfHeaders;
}

- (NSInteger)numberOfFootersInSectionAtIndex:(NSInteger)sectionIndex includeChildDataSouces:(BOOL)includeChildDataSources
{
    NSInteger numberOfFooters = [super numberOfFootersInSectionAtIndex:sectionIndex includeChildDataSouces:NO];
    if (includeChildDataSources)
        numberOfFooters += [_selectedDataSource numberOfFootersInSectionAtIndex:sectionIndex includeChildDataSouces:YES];
    return numberOfFooters;
}

- (void)configureDefaultHeader
{
    AAPLSupplementaryItem *defaultHeader = [self headerForKey:AAPLSegmentedDataSourceHeaderKey];
    if (self.shouldDisplayDefaultHeader) {
        if (!defaultHeader)
            (void)[self segmentedControlHeader];
    }
    else {
        if (defaultHeader)
            [self removeHeaderForKey:AAPLSegmentedDataSourceHeaderKey];
    }
}

- (NSArray *)indexPathsForSupplementaryItem:(AAPLSupplementaryItem *)supplementaryItem header:(BOOL)header
{
    if (header) {
        NSArray *result = [super indexPathsForSupplementaryItem:supplementaryItem header:header];
        if (result.count)
            return result;

        // If the metrics aren't defined on this data source, check the selected data source
        result = [_selectedDataSource indexPathsForSupplementaryItem:supplementaryItem header:header];

        // Need to update the index paths of the selected data source to reflect any headers defined in this data source
        NSMutableArray *adjusted = [NSMutableArray arrayWithCapacity:result.count];
        NSInteger numberOfIndexPaths = result.count;

        for (NSInteger resultIndex = 0; resultIndex < numberOfIndexPaths; ++resultIndex) {
            NSIndexPath *indexPath = result[resultIndex];
            NSInteger sectionIndex = indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex;
            NSInteger itemIndex = indexPath.length > 1 ? indexPath.item : [indexPath indexAtPosition:0];

            NSInteger numberOfHeaders = [self numberOfHeadersInSectionAtIndex:sectionIndex includeChildDataSouces:NO];
            NSInteger headerIndex = itemIndex + numberOfHeaders;
            NSIndexPath *newIndexPath = (AAPLGlobalSectionIndex == sectionIndex) ? [NSIndexPath indexPathWithIndex:headerIndex] : [NSIndexPath indexPathForItem:headerIndex inSection:sectionIndex];
            [adjusted addObject:newIndexPath];
        }

        return adjusted;
    }
    else {
        NSArray *result = [_selectedDataSource indexPathsForSupplementaryItem:supplementaryItem header:header];
        if (result.count)
            return result;

        // If the metrics aren't defined on the selected data source, check this data source
        result = [super indexPathsForSupplementaryItem:supplementaryItem header:header];

        // Need to update the index paths of the selected data source to reflect any headers defined in this data source
        NSMutableArray *adjusted = [NSMutableArray arrayWithCapacity:result.count];
        NSInteger numberOfIndexPaths = result.count;

        for (NSInteger resultIndex = 0; resultIndex < numberOfIndexPaths; ++resultIndex) {
            NSIndexPath *indexPath = result[resultIndex];
            NSInteger sectionIndex = indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex;
            NSInteger itemIndex = indexPath.length > 1 ? indexPath.item : [indexPath indexAtPosition:0];

            NSInteger numberOfFooters = [_selectedDataSource numberOfFootersInSectionAtIndex:sectionIndex includeChildDataSouces:NO];
            NSInteger footerIndex = itemIndex + numberOfFooters;
            NSIndexPath *newIndexPath = (AAPLGlobalSectionIndex == sectionIndex) ? [NSIndexPath indexPathWithIndex:footerIndex] : [NSIndexPath indexPathForItem:footerIndex inSection:sectionIndex];
            [adjusted addObject:newIndexPath];
        }

        return adjusted;
    }
}

- (void)findSupplementaryItemForHeader:(BOOL)header indexPath:(NSIndexPath *)indexPath usingBlock:(void(^)(AAPLDataSource *dataSource, NSIndexPath *localIndexPath, AAPLSupplementaryItem *supplementaryItem))block
{
    NSParameterAssert(block != nil);

    [self configureDefaultHeader];

    NSInteger sectionIndex = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex);
    NSInteger itemIndex = (indexPath.length > 1 ? indexPath.item : [indexPath indexAtPosition:0]);

    BOOL globalSection = (AAPLGlobalSectionIndex == sectionIndex);

    if (header) {
        NSInteger numberOfHeaders = [self numberOfHeadersInSectionAtIndex:sectionIndex includeChildDataSouces:NO];
        if (itemIndex < numberOfHeaders)
            return [super findSupplementaryItemForHeader:header indexPath:indexPath usingBlock:block];

        itemIndex -= numberOfHeaders;
        NSIndexPath *childIndexPath = globalSection ? [NSIndexPath indexPathWithIndex:itemIndex] : [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex];
        [_selectedDataSource findSupplementaryItemForHeader:header indexPath:childIndexPath usingBlock:block];
    }
    else {
        NSInteger numberOfFooters = [_selectedDataSource numberOfFootersInSectionAtIndex:sectionIndex includeChildDataSouces:YES];
        if (itemIndex < numberOfFooters)
            return [_selectedDataSource findSupplementaryItemForHeader:header indexPath:indexPath usingBlock:block];

        itemIndex -= numberOfFooters;
        NSIndexPath *selfIndexPath = globalSection ? [NSIndexPath indexPathWithIndex:itemIndex] : [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex];
        [super findSupplementaryItemForHeader:header indexPath:selfIndexPath usingBlock:block];
    }
}

- (AAPLDataSourceSectionMetrics *)snapshotMetricsForSectionAtIndex:(NSInteger)sectionIndex
{
    [self configureDefaultHeader];

    AAPLDataSourceSectionMetrics *metrics = [_selectedDataSource snapshotMetricsForSectionAtIndex:sectionIndex];
    AAPLDataSourceSectionMetrics *enclosingMetrics = [super snapshotMetricsForSectionAtIndex:sectionIndex];

    [enclosingMetrics applyValuesFromMetrics:metrics];
    return enclosingMetrics;
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];

    for (AAPLDataSource *dataSource in self.dataSources)
        [dataSource registerReusableViewsWithCollectionView:collectionView];
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

- (void)beginLoadingContentWithProgress:(AAPLLoadingProgress *)progress
{
    // Only load the currently selected data source. Others will be loaded as necessary.
    [_selectedDataSource loadContent];

    // Make certain we call super to ensure the correct behaviour still occurs for this data source.
    [super beginLoadingContentWithProgress:progress];
}

- (void)resetContent
{
    for (AAPLDataSource *dataSource in self.dataSources)
        [dataSource resetContent];
    [super resetContent];
}

#pragma mark - Placeholders

- (void)updatePlaceholderView:(AAPLCollectionPlaceholderView *)placeholderView forSectionAtIndex:(NSInteger)sectionIndex
{
    [_selectedDataSource updatePlaceholderView:placeholderView forSectionAtIndex:sectionIndex];
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
    // When we're showing a placeholder, we have to lie to the collection view about the number of items we have. Otherwise, it will ask for layout attributes that we don't have.
    return self.shouldShowPlaceholder ? 0 : [_selectedDataSource collectionView:collectionView numberOfItemsInSection:section];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [_selectedDataSource collectionView:collectionView cellForItemAtIndexPath:indexPath];
}

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
        // This isn't the active data source, so just go ahead and update it, because the changes won't be reflected in the collection view.
        if (update)
            update();
        if (complete)
            complete();
        return;
    }

    [self performUpdate:update complete:complete];
}

- (void)dataSource:(AAPLDataSource *)dataSource didPresentActivityIndicatorForSections:(NSIndexSet *)sections
{
    if (dataSource != _selectedDataSource)
        return;

    [self presentActivityIndicatorForSections:sections];
}

/// Present a placeholder for a set of sections. The sections must be contiguous.
- (void)dataSource:(AAPLDataSource *)dataSource didPresentPlaceholderForSections:(NSIndexSet *)sections
{
    if (dataSource != _selectedDataSource)
        return;

    [self presentPlaceholder:nil forSections:sections];
}

/// Remove a placeholder for a set of sections.
- (void)dataSource:(AAPLDataSource *)dataSource didDismissPlaceholderForSections:(NSIndexSet *)sections
{
    if (dataSource != _selectedDataSource)
        return;

    [self dismissPlaceholderForSections:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didUpdateSupplementaryItem:(AAPLSupplementaryItem *)supplementaryItem atIndexPaths:(NSArray *)indexPaths header:(BOOL)header
{
    if (dataSource != _selectedDataSource)
        return;
    
    [self notifyContentUpdatedForSupplementaryItem:supplementaryItem atIndexPaths:indexPaths header:header];
}

@end
