/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of AAPLDataSource with multiple child data sources. Child data sources may have multiple sections. Load content messages will be sent to all child data sources.
 */

#import "AAPLDataSource_Private.h"
#import "AAPLComposedDataSource.h"
#import "AAPLDataSourceMapping.h"
#import "AAPLPlaceholderView.h"

@interface AAPLComposedDataSource () <AAPLDataSourceDelegate>
@property (nonatomic, strong) NSMutableArray *mappings;
@property (nonatomic, strong) NSMapTable *dataSourceToMappings;
@property (nonatomic, strong) NSMutableDictionary *globalSectionToMappings;
@end

@implementation AAPLComposedDataSource {
    NSInteger _numberOfSections;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _mappings = [[NSMutableArray alloc] init];
    _dataSourceToMappings = [[NSMapTable alloc] initWithKeyOptions:NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory capacity:1];
    _globalSectionToMappings = [[NSMutableDictionary alloc] init];

    return self;
}

- (void)updateMappings
{
    _numberOfSections = 0;
    [_globalSectionToMappings removeAllObjects];

    for (AAPLDataSourceMapping *mapping in _mappings) {
        [mapping updateMappingStartingAtGlobalSection:_numberOfSections withBlock:^(NSInteger sectionIndex) {
            _globalSectionToMappings[@(sectionIndex)] = mapping;
        }];
        _numberOfSections += mapping.numberOfSections;
    }
}

- (NSUInteger)sectionForDataSource:(AAPLDataSource *)dataSource
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];

    return [mapping globalSectionForLocalSection:0];
}

- (AAPLDataSource *)dataSourceForSectionAtIndex:(NSInteger)sectionIndex
{
    AAPLDataSourceMapping *mapping = _globalSectionToMappings[@(sectionIndex)];
    return mapping.dataSource;
}

- (NSIndexPath *)localIndexPathForGlobalIndexPath:(NSIndexPath *)globalIndexPath
{
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:globalIndexPath.section];
    return [mapping localIndexPathForGlobalIndexPath:globalIndexPath];
}

- (AAPLDataSourceMapping *)mappingForGlobalSection:(NSInteger)section
{
    AAPLDataSourceMapping *mapping = _globalSectionToMappings[@(section)];
    return mapping;
}

- (AAPLDataSourceMapping *)mappingForDataSource:(AAPLDataSource *)dataSource
{
    AAPLDataSourceMapping *mapping = [_dataSourceToMappings objectForKey:dataSource];
    return mapping;
}

- (NSIndexSet *)globalSectionsForLocal:(NSIndexSet *)localSections dataSource:(AAPLDataSource *)dataSource
{
    NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];
    [localSections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        [result addIndex:[mapping globalSectionForLocalSection:localSection]];
    }];
    return result;
}

- (NSArray *)globalIndexPathsForLocal:(NSArray *)localIndexPaths dataSource:(AAPLDataSource *)dataSource
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[localIndexPaths count]];
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];
    for (NSIndexPath *localIndexPath in localIndexPaths) {
        [result addObject:[mapping globalIndexPathForLocalIndexPath:localIndexPath]];
    }

    return result;
}

- (void)enumerateDataSourcesWithBlock:(void(^)(AAPLDataSource *dataSource, BOOL *stop))block
{
    NSParameterAssert(block != nil);

    BOOL stop = NO;
    for (id key in _dataSourceToMappings) {
        AAPLDataSourceMapping *mapping = [_dataSourceToMappings objectForKey:key];
        block(mapping.dataSource, &stop);
        if (stop)
            break;
    }
}

- (id)itemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:indexPath.section];

    NSIndexPath *mappedIndexPath = [mapping localIndexPathForGlobalIndexPath:indexPath];

    return [mapping.dataSource itemAtIndexPath:mappedIndexPath];
}

- (NSArray*)indexPathsForItem:(id)object
{
    NSMutableArray *results = [NSMutableArray array];

    [self enumerateDataSourcesWithBlock:^(AAPLDataSource *dataSource, BOOL *stop) {
        AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];
        NSArray *indexPaths = [dataSource indexPathsForItem:object];

        if (![indexPaths count])
            return;

        for (NSIndexPath *localIndexPath in indexPaths)
            [results addObject:[mapping globalIndexPathForLocalIndexPath:localIndexPath]];
    }];

    return results;
}

- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:indexPath.section];
    AAPLDataSource *dataSource = mapping.dataSource;
    NSIndexPath *localIndexPath = [mapping localIndexPathForGlobalIndexPath:indexPath];

    [dataSource removeItemAtIndexPath:localIndexPath];
}

- (NSArray *)primaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:indexPath.section];
    AAPLDataSource *dataSource = mapping.dataSource;
    NSIndexPath *localIndexPath = [mapping localIndexPathForGlobalIndexPath:indexPath];

    return [dataSource primaryActionsForItemAtIndexPath:localIndexPath];
}

- (NSArray *)secondaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:indexPath.section];
    AAPLDataSource *dataSource = mapping.dataSource;
    NSIndexPath *localIndexPath = [mapping localIndexPathForGlobalIndexPath:indexPath];

    return [dataSource secondaryActionsForItemAtIndexPath:localIndexPath];
}

- (void)didBecomeActive
{
    [super didBecomeActive];
    [self enumerateDataSourcesWithBlock:^(AAPLDataSource *dataSource, BOOL *stop) {
        [dataSource didBecomeActive];
    }];
}

- (void)willResignActive
{
    [super willResignActive];
    [self enumerateDataSourcesWithBlock:^(AAPLDataSource *dataSource, BOOL *stop) {
        [dataSource willResignActive];
    }];
}

- (void)presentActivityIndicatorForSections:(NSIndexSet *)sections
{
    // Based on the rule that if any child is loading, the composed data source is loading, we're going to expand the sections to cover the entire data source if any child asks for an activity indicator AND we're loading.
    if ([self.loadingState isEqualToString:AAPLLoadStateLoadingContent])
        sections = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.numberOfSections)];

    [super presentActivityIndicatorForSections:sections];
}

- (void)updatePlaceholderView:(AAPLCollectionPlaceholderView *)placeholderView forSectionAtIndex:(NSInteger)sectionIndex
{
    // Need to determine which data source gets a crack at updating the placeholder

    // If the sectionIndex is 0 and we're going to show an activity indicator, let the super class handle it. Although, sectionIndex probably shouldn't ever be anything BUT 0 when we're going to show an activity indicator.
    if (0 == sectionIndex && self.shouldShowActivityIndicator) {
        [super updatePlaceholderView:placeholderView forSectionAtIndex:sectionIndex];
        return;
    }

    // If this data source is showing a placeholder and the sectionIndex is 0, allow the super class to handle it. It's probably an error if we get a sectionIndex other than 0.
    if (0 == sectionIndex && self.shouldShowPlaceholder) {
        [super updatePlaceholderView:placeholderView forSectionAtIndex:sectionIndex];
        return;
    }

    // This data source doesn't want to handle the placeholder. Find a child data source that should.
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:sectionIndex];
    AAPLDataSource *dataSource = mapping.dataSource;
    NSInteger localSectionIndex = [mapping localSectionForGlobalSection:sectionIndex];
    [dataSource updatePlaceholderView:placeholderView forSectionAtIndex:localSectionIndex];
}

#pragma mark - AAPLComposedDataSource API

- (void)addDataSource:(AAPLDataSource *)dataSource
{
    NSParameterAssert(dataSource != nil);

    dataSource.delegate = self;

    AAPLDataSourceMapping *mappingForDataSource = [_dataSourceToMappings objectForKey:dataSource];
    NSAssert(mappingForDataSource == nil, @"tried to add data source more than once: %@", dataSource);

    mappingForDataSource = [[AAPLDataSourceMapping alloc] initWithDataSource:dataSource];
    [_mappings addObject:mappingForDataSource];
    [_dataSourceToMappings setObject:mappingForDataSource forKey:dataSource];

    [self updateMappings];
    NSMutableIndexSet *addedSections = [NSMutableIndexSet indexSet];
    NSUInteger numberOfSections = dataSource.numberOfSections;

    for (NSUInteger sectionIdx = 0; sectionIdx < numberOfSections; ++sectionIdx)
        [addedSections addIndex:[mappingForDataSource globalSectionForLocalSection:sectionIdx]];
    [self notifySectionsInserted:addedSections];
}

- (void)removeDataSource:(AAPLDataSource *)dataSource
{
    AAPLDataSourceMapping *mappingForDataSource = [_dataSourceToMappings objectForKey:dataSource];
    NSAssert(mappingForDataSource != nil, @"Data source not found in mapping");

    NSMutableIndexSet *removedSections = [NSMutableIndexSet indexSet];
    NSUInteger numberOfSections = dataSource.numberOfSections;

    for (NSUInteger sectionIdx = 0; sectionIdx < numberOfSections; ++sectionIdx)
        [removedSections addIndex:[mappingForDataSource globalSectionForLocalSection:sectionIdx]];

    [_dataSourceToMappings removeObjectForKey:dataSource];
    [_mappings removeObject:mappingForDataSource];

    dataSource.delegate = nil;

    [self updateMappings];

    [self notifySectionsRemoved:removedSections];
}

#pragma mark - AAPLDataSource methods

- (NSInteger)numberOfSections
{
    [self updateMappings];
    return _numberOfSections;
}

- (NSInteger)numberOfHeadersInSectionAtIndex:(NSInteger)sectionIndex includeChildDataSouces:(BOOL)includeChildDataSources
{
    NSInteger numberOfHeaders = [super numberOfHeadersInSectionAtIndex:sectionIndex includeChildDataSouces:NO];
    if (includeChildDataSources) {
        AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:sectionIndex];
        NSInteger localSection = [mapping localSectionForGlobalSection:sectionIndex];
        AAPLDataSource *dataSource = mapping.dataSource;
        numberOfHeaders += [dataSource numberOfHeadersInSectionAtIndex:localSection includeChildDataSouces:YES];
    }
    return numberOfHeaders;
}

- (NSInteger)numberOfFootersInSectionAtIndex:(NSInteger)sectionIndex includeChildDataSouces:(BOOL)includeChildDataSources
{
    NSInteger numberOfFooters = [super numberOfFootersInSectionAtIndex:sectionIndex includeChildDataSouces:NO];
    if (includeChildDataSources) {
        AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:sectionIndex];
        NSInteger localSection = [mapping localSectionForGlobalSection:sectionIndex];
        AAPLDataSource *dataSource = mapping.dataSource;
        numberOfFooters += [dataSource numberOfFootersInSectionAtIndex:localSection includeChildDataSouces:YES];
    }
    return numberOfFooters;
}

- (NSArray *)indexPathsForSupplementaryItem:(AAPLSupplementaryItem *)supplementaryItem header:(BOOL)header
{
    __block NSArray *result = nil;

    if (header) {
        result = [super indexPathsForSupplementaryItem:supplementaryItem header:header];
        if (result.count)
            return result;

        [self.mappings enumerateObjectsUsingBlock:^(AAPLDataSourceMapping *mapping, NSUInteger mappingIndex, BOOL *stop) {
            AAPLDataSource *dataSource = mapping.dataSource;

            // If the metrics aren't defined on this data source, check the selected data source
            result = [dataSource indexPathsForSupplementaryItem:supplementaryItem header:header];
            result = [mapping globalIndexPathsForLocalIndexPaths:result];

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

            *stop = (adjusted.count > 0);
            result = [NSArray arrayWithArray:adjusted];
        }];

        return result;
    }
    else {
        [self.mappings enumerateObjectsUsingBlock:^(AAPLDataSourceMapping *mapping, NSUInteger mappingIndex, BOOL *stop) {
            AAPLDataSource *dataSource = mapping.dataSource;

            // If the metrics aren't defined on this data source, check the selected data source
            result = [dataSource indexPathsForSupplementaryItem:supplementaryItem header:header];
            result = [mapping globalIndexPathsForLocalIndexPaths:result];
            *stop = (result.count > 0);
        }];

        if (result.count)
            return result;

        // If the supplementary metrics weren't found in the child data sources, look in this data source
        result = [super indexPathsForSupplementaryItem:supplementaryItem header:header];

        // Need to update the index paths of the found footers to allow for footers defined in the child data sources
        NSMutableArray *adjusted = [NSMutableArray arrayWithCapacity:result.count];
        NSInteger numberOfIndexPaths = result.count;

        for (NSInteger resultIndex = 0; resultIndex < numberOfIndexPaths; ++resultIndex) {
            NSIndexPath *indexPath = result[resultIndex];
            NSInteger sectionIndex = indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex;
            NSInteger itemIndex = indexPath.length > 1 ? indexPath.item : [indexPath indexAtPosition:0];

            AAPLDataSource *sectionDataSource = [self dataSourceForSectionAtIndex:sectionIndex];
            NSInteger numberOfFooters = [sectionDataSource numberOfFootersInSectionAtIndex:sectionIndex includeChildDataSouces:YES];
            NSInteger footerIndex = itemIndex + numberOfFooters;
            NSIndexPath *newIndexPath = (AAPLGlobalSectionIndex == sectionIndex) ? [NSIndexPath indexPathWithIndex:footerIndex] : [NSIndexPath indexPathForItem:footerIndex inSection:sectionIndex];
            [adjusted addObject:newIndexPath];
        }

        return [NSArray arrayWithArray:adjusted];
    }
}

- (void)findSupplementaryItemForHeader:(BOOL)header indexPath:(NSIndexPath *)indexPath usingBlock:(void (^)(AAPLDataSource *, NSIndexPath *, AAPLSupplementaryItem *))block
{
    NSParameterAssert(block != nil);

    NSInteger sectionIndex = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex);
    NSInteger itemIndex = (indexPath.length > 1 ? indexPath.item : [indexPath indexAtPosition:0]);

    BOOL globalSection = (AAPLGlobalSectionIndex == sectionIndex);

    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:sectionIndex];
    NSInteger localSection = [mapping localSectionForGlobalSection:sectionIndex];
    AAPLDataSource *dataSource = mapping.dataSource;

    if (header) {
        NSInteger numberOfHeaders = [self numberOfHeadersInSectionAtIndex:sectionIndex includeChildDataSouces:NO];
        if (itemIndex < numberOfHeaders)
            return [super findSupplementaryItemForHeader:header indexPath:indexPath usingBlock:block];

        itemIndex -= numberOfHeaders;

        NSIndexPath *localIndexPath = [NSIndexPath indexPathForItem:itemIndex inSection:localSection];
        return [dataSource findSupplementaryItemForHeader:header indexPath:localIndexPath usingBlock:block];
    }
    else {
        NSInteger numberOfFooters = [dataSource numberOfFootersInSectionAtIndex:sectionIndex includeChildDataSouces:YES];
        if (itemIndex < numberOfFooters){
            NSIndexPath *localIndexPath = [NSIndexPath indexPathForItem:itemIndex inSection:localSection];
            return [dataSource findSupplementaryItemForHeader:header indexPath:localIndexPath usingBlock:block];
        }

        itemIndex -= numberOfFooters;
        NSIndexPath *selfIndexPath = globalSection ? [NSIndexPath indexPathWithIndex:itemIndex] : [NSIndexPath indexPathForItem:itemIndex inSection:localSection];
        return [super findSupplementaryItemForHeader:header indexPath:selfIndexPath usingBlock:block];
    }
}

- (AAPLDataSourceSectionMetrics *)snapshotMetricsForSectionAtIndex:(NSInteger)sectionIndex
{
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:sectionIndex];
    NSInteger localSection = [mapping localSectionForGlobalSection:sectionIndex];
    AAPLDataSource *dataSource = mapping.dataSource;

    AAPLDataSourceSectionMetrics *metrics = [dataSource snapshotMetricsForSectionAtIndex:localSection];
    AAPLDataSourceSectionMetrics *enclosingMetrics = [super snapshotMetricsForSectionAtIndex:sectionIndex];

    [enclosingMetrics applyValuesFromMetrics:metrics];
    return enclosingMetrics;
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];

    [self enumerateDataSourcesWithBlock:^(AAPLDataSource *dataSource, BOOL *stop) {
        [dataSource registerReusableViewsWithCollectionView:collectionView];
    }];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canEditItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:indexPath.section];
    UICollectionView *wrapper = [AAPLCollectionViewWrapper wrapperForCollectionView:collectionView mapping:mapping];
    AAPLDataSource *dataSource = mapping.dataSource;
    NSIndexPath *localIndexPath = [mapping localIndexPathForGlobalIndexPath:indexPath];

    return [dataSource collectionView:wrapper canEditItemAtIndexPath:localIndexPath];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:indexPath.section];
    UICollectionView *wrapper = [AAPLCollectionViewWrapper wrapperForCollectionView:collectionView mapping:mapping];
    AAPLDataSource *dataSource = mapping.dataSource;
    NSIndexPath *localIndexPath = [mapping localIndexPathForGlobalIndexPath:indexPath];

    return [dataSource collectionView:wrapper canMoveItemAtIndexPath:localIndexPath];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    // This is a bit simplistic: basically, if the move is between data sources, I'm going to assume the answer is NO. Subclasses can improve upon this if desired.
    AAPLDataSourceMapping *fromMapping = [self mappingForGlobalSection:indexPath.section];
    AAPLDataSourceMapping *toMapping = [self mappingForGlobalSection:destinationIndexPath.section];

    if (toMapping != fromMapping)
        return NO;

    UICollectionView *wrapper = [AAPLCollectionViewWrapper wrapperForCollectionView:collectionView mapping:fromMapping];
    AAPLDataSource *dataSource = fromMapping.dataSource;

    NSIndexPath *localFromIndexPath = [fromMapping localIndexPathForGlobalIndexPath:indexPath];
    NSIndexPath *localToIndexPath = [fromMapping localIndexPathForGlobalIndexPath:destinationIndexPath];

    return [dataSource collectionView:wrapper canMoveItemAtIndexPath:localFromIndexPath toIndexPath:localToIndexPath];
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    // This is a bit simplistic: basically, if the move is between data sources, I'm going to assume the answer is NO. Subclasses can improve upon this if desired.
    AAPLDataSourceMapping *fromMapping = [self mappingForGlobalSection:indexPath.section];
    AAPLDataSourceMapping *toMapping = [self mappingForGlobalSection:destinationIndexPath.section];

    if (toMapping != fromMapping)
        return;

    UICollectionView *wrapper = [AAPLCollectionViewWrapper wrapperForCollectionView:collectionView mapping:fromMapping];
    AAPLDataSource *dataSource = fromMapping.dataSource;

    NSIndexPath *localFromIndexPath = [fromMapping localIndexPathForGlobalIndexPath:indexPath];
    NSIndexPath *localToIndexPath = [fromMapping localIndexPathForGlobalIndexPath:destinationIndexPath];

    [dataSource collectionView:wrapper moveItemAtIndexPath:localFromIndexPath toIndexPath:localToIndexPath];
}

#pragma mark - AAPLContentLoading

- (void)endLoadingContentWithState:(NSString *)state error:(NSError *)error update:(dispatch_block_t)update
{
    // For composed data sources, if a subclass implements -loadContentWithProgress: and reports a final state of AAPLLoadStateNoContent or AAPLLoadStateError, it doesn't matter what our children report. We're done.
    if ([AAPLLoadStateNoContent isEqualToString:state] || [AAPLLoadStateError isEqualToString:state]) {
        [super endLoadingContentWithState:state error:error update:update];
        return;
    }

    // That means we should be in AAPLLoadStateContentLoaded now…
    NSAssert([AAPLLoadStateContentLoaded isEqualToString:state], @"We're in an unexpected state: %@", state);

    // We need to wait for all the loading child data sources to complete
    dispatch_group_t loadingGroup = dispatch_group_create();
    [self enumerateDataSourcesWithBlock:^(AAPLDataSource *dataSource, BOOL *stop) {
        NSString *loadingState = dataSource.loadingState;
        // Skip data sources that aren't loading
        if (![AAPLLoadStateLoadingContent isEqualToString:loadingState] && ![AAPLLoadStateRefreshingContent isEqualToString:loadingState])
            return;

        dispatch_group_enter(loadingGroup);
        [dataSource whenLoaded:^{
            dispatch_group_leave(loadingGroup);
        }];
    }];

    // When all the child data sources have loaded, we need to figure out what the result state is.
    dispatch_group_notify(loadingGroup, dispatch_get_main_queue(), ^{
        NSMutableSet *resultSet = [NSMutableSet set];
        [self enumerateDataSourcesWithBlock:^(AAPLDataSource *dataSource, BOOL *stop) {
            [resultSet addObject:dataSource.loadingState];
        }];

        NSString *finalState = state;

        // resultSet will hold the deduplicated set of loading states. We want to be a bit clever here. If all the data sources yielded no content, we should transition to no content regardless of what our loading result was. Otherwise, we'll transition to content loaded and allow each child data source to present its own placeholder as appropriate.
        if (1 == resultSet.count && [AAPLLoadStateNoContent isEqualToString:resultSet.anyObject])
            finalState = AAPLLoadStateNoContent;

        [super endLoadingContentWithState:finalState error:error update:update];
    });
}

- (void)beginLoadingContentWithProgress:(AAPLLoadingProgress *)progress
{
    // Before we start loading any content for the composed data source itself, make certain all the child data sources have started loading.
    [self enumerateDataSourcesWithBlock:^(AAPLDataSource *dataSource, BOOL *stop) {
        [dataSource loadContent];
    }];

    [self loadContentWithProgress:progress];
}

- (void)resetContent
{
    [super resetContent];
    [self enumerateDataSourcesWithBlock:^(AAPLDataSource *dataSource, BOOL *stop) {
        [dataSource resetContent];
    }];
}

#pragma mark - UICollectionViewDataSource methods

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    [self updateMappings];

    // When we're showing a placeholder, we have to lie to the collection view about the number of items we have. Otherwise, it will ask for layout attributes that we don't have.
    if (self.shouldShowPlaceholder)
        return 0;

    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:section];
    UICollectionView *wrapper = [AAPLCollectionViewWrapper wrapperForCollectionView:collectionView mapping:mapping];
    NSInteger localSection = [mapping localSectionForGlobalSection:section];
    AAPLDataSource *dataSource = mapping.dataSource;

    NSInteger numberOfSections = [dataSource numberOfSectionsInCollectionView:wrapper];
    NSAssert(localSection < numberOfSections, @"local section is out of bounds for composed data source");

    return [dataSource collectionView:wrapper numberOfItemsInSection:localSection];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLDataSourceMapping *mapping = [self mappingForGlobalSection:indexPath.section];
    UICollectionView *wrapper = [AAPLCollectionViewWrapper wrapperForCollectionView:collectionView mapping:mapping];
    AAPLDataSource *dataSource = mapping.dataSource;
    NSIndexPath *localIndexPath = [mapping localIndexPathForGlobalIndexPath:indexPath];

    return [dataSource collectionView:wrapper cellForItemAtIndexPath:localIndexPath];
}

#pragma mark - AAPLDataSourceDelegate

- (void)dataSource:(AAPLDataSource *)dataSource didInsertItemsAtIndexPaths:(NSArray *)indexPaths
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];
    NSArray *globalIndexPaths = [mapping globalIndexPathsForLocalIndexPaths:indexPaths];

    [self notifyItemsInsertedAtIndexPaths:globalIndexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveItemsAtIndexPaths:(NSArray *)indexPaths
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];
    NSArray *globalIndexPaths = [mapping globalIndexPathsForLocalIndexPaths:indexPaths];

    [self notifyItemsRemovedAtIndexPaths:globalIndexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshItemsAtIndexPaths:(NSArray *)indexPaths
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];
    NSArray *globalIndexPaths = [mapping globalIndexPathsForLocalIndexPaths:indexPaths];

    [self notifyItemsRefreshedAtIndexPaths:globalIndexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveItemAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];
    NSIndexPath *globalFromIndexPath = [mapping globalIndexPathForLocalIndexPath:fromIndexPath];
    NSIndexPath *globalNewIndexPath = [mapping globalIndexPathForLocalIndexPath:newIndexPath];

    [self notifyItemMovedFromIndexPath:globalFromIndexPath toIndexPaths:globalNewIndexPath];
}

- (void)dataSource:(AAPLDataSource *)dataSource didInsertSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];

    [self updateMappings];

    NSMutableIndexSet *globalSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger localSectionIndex, BOOL *stop) {
        [globalSections addIndex:[mapping globalSectionForLocalSection:localSectionIndex]];
    }];

    [self notifySectionsInserted:globalSections direction:direction];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];

    [self updateMappings];

    NSMutableIndexSet *globalSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger localSectionIndex, BOOL *stop) {
        [globalSections addIndex:[mapping globalSectionForLocalSection:localSectionIndex]];
    }];

    [self notifySectionsRemoved:globalSections direction:direction];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshSections:(NSIndexSet *)sections
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];

    NSMutableIndexSet *globalSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger localSectionIndex, BOOL *stop) {
        [globalSections addIndex:[mapping globalSectionForLocalSection:localSectionIndex]];
    }];

    [self notifySectionsRefreshed:globalSections];
    [self updateMappings];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveSection:(NSInteger)section toSection:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];

    NSInteger globalSection = [mapping globalSectionForLocalSection:section];
    NSInteger globalNewSection = [mapping globalSectionForLocalSection:newSection];

    [self updateMappings];

    [self notifySectionMovedFrom:globalSection to:globalNewSection direction:direction];
}

- (void)dataSourceDidReloadData:(AAPLDataSource *)dataSource
{
    [self notifyDidReloadData];
}

- (void)dataSource:(AAPLDataSource *)dataSource performBatchUpdate:(dispatch_block_t)update complete:(dispatch_block_t)complete
{
    [self performUpdate:update complete:complete];
}

- (void)dataSource:(AAPLDataSource *)dataSource didPresentActivityIndicatorForSections:(NSIndexSet *)sections
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];

    NSMutableIndexSet *globalSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger localSectionIndex, BOOL *stop) {
        [globalSections addIndex:[mapping globalSectionForLocalSection:localSectionIndex]];
    }];

    [self presentActivityIndicatorForSections:globalSections];
}

/// Present a placeholder for a set of sections. The sections must be contiguous.
- (void)dataSource:(AAPLDataSource *)dataSource didPresentPlaceholderForSections:(NSIndexSet *)sections
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];

    NSMutableIndexSet *globalSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger localSectionIndex, BOOL *stop) {
        [globalSections addIndex:[mapping globalSectionForLocalSection:localSectionIndex]];
    }];

    [self presentPlaceholder:nil forSections:globalSections];
}

/// Remove a placeholder for a set of sections.
- (void)dataSource:(AAPLDataSource *)dataSource didDismissPlaceholderForSections:(NSIndexSet *)sections
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];

    NSMutableIndexSet *globalSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger localSectionIndex, BOOL *stop) {
        [globalSections addIndex:[mapping globalSectionForLocalSection:localSectionIndex]];
    }];

    [self dismissPlaceholderForSections:globalSections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didUpdateSupplementaryItem:(AAPLSupplementaryItem *)supplementaryItem atIndexPaths:(NSArray *)indexPaths header:(BOOL)header
{
    AAPLDataSourceMapping *mapping = [self mappingForDataSource:dataSource];
    NSArray *globalIndexPaths = [mapping globalIndexPathsForLocalIndexPaths:indexPaths];
    
    [self notifyContentUpdatedForSupplementaryItem:supplementaryItem atIndexPaths:globalIndexPaths header:header];
}
@end
