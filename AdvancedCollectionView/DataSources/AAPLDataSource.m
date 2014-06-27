/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The base data source class.
  
 */

#import "AAPLDataSource_Private.h"
#import "AAPLLayoutMetrics_Private.h"
#import "AAPLPlaceholderView.h"
#import "NSObject+KVOBlock.h"
#import <libkern/OSAtomic.h>

#define AAPL_ASSERT_MAIN_THREAD NSAssert([NSThread isMainThread], @"This method must be called on the main thread")

@interface AAPLDataSource () <AAPLStateMachineDelegate>
@property (nonatomic, strong) NSMutableDictionary *sectionMetrics;
@property (nonatomic, strong) NSMutableArray *headers;
@property (nonatomic, strong) NSMutableDictionary *headersByKey;
@property (nonatomic, strong) AAPLLoadableContentStateMachine *stateMachine;
@property (nonatomic, strong) AAPLCollectionPlaceholderView *placeholderView;
@property (nonatomic, copy) dispatch_block_t pendingUpdateBlock;
@property (nonatomic) BOOL loadingComplete;
@property (nonatomic, weak) AAPLLoading *loadingInstance;
@end

@implementation AAPLDataSource
@synthesize loadingError = _loadingError;

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _defaultMetrics = [[AAPLLayoutSectionMetrics alloc] init];
    return self;
}

- (BOOL)isRootDataSource
{
    id delegate = self.delegate;
    return [delegate isKindOfClass:[AAPLDataSource class]] ? NO : YES;
}

- (AAPLDataSource *)dataSourceForSectionAtIndex:(NSInteger)sectionIndex
{
    return self;
}

- (NSIndexPath *)localIndexPathForGlobalIndexPath:(NSIndexPath *)globalIndexPath
{
    return globalIndexPath;
}

- (NSArray *)indexPathsForItem:(id)object
{
    NSAssert(NO, @"Should be implemented by subclasses");
    return nil;
}

- (id)itemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"Should be implemented by subclasses");
    return nil;
}

- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"Should be implemented by subclasses");
    return;
}

- (NSInteger)numberOfSections
{
    return 1;
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    NSInteger numberOfSections = self.numberOfSections;

    AAPLLayoutSectionMetrics *globalMetrics = [self snapshotMetricsForSectionAtIndex:AAPLGlobalSection];
    for (AAPLLayoutSupplementaryMetrics* headerMetrics in globalMetrics.headers)
        [collectionView registerClass:headerMetrics.supplementaryViewClass forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:headerMetrics.reuseIdentifier];

    for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
        AAPLLayoutSectionMetrics *metrics = [self snapshotMetricsForSectionAtIndex:sectionIndex];

        for (AAPLLayoutSupplementaryMetrics* headerMetrics in metrics.headers)
            [collectionView registerClass:headerMetrics.supplementaryViewClass forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:headerMetrics.reuseIdentifier];
        for (AAPLLayoutSupplementaryMetrics* footerMetrics in metrics.footers)
            [collectionView registerClass:footerMetrics.supplementaryViewClass forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:footerMetrics.reuseIdentifier];
    }

    [collectionView registerClass:[AAPLCollectionPlaceholderView class] forSupplementaryViewOfKind:AAPLCollectionElementKindPlaceholder withReuseIdentifier:NSStringFromClass([AAPLCollectionPlaceholderView class])];
}

- (CGSize)collectionView:(UICollectionView *)collectionView sizeFittingSize:(CGSize)size forItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"Should be implemented by subclasses");
    return size;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canEditItemAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    return NO;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    NSAssert(NO, @"Should be implemented by subclasses");
}

#pragma mark - AAPLContentLoading methods

- (AAPLLoadableContentStateMachine *)stateMachine
{
    if (_stateMachine)
        return _stateMachine;

    _stateMachine = [[AAPLLoadableContentStateMachine alloc] init];
    _stateMachine.delegate = self;
    return _stateMachine;
}

- (NSString *)loadingState
{
    // Don't cause the creation of the state machine just by inspection of the loading state.
    if (!_stateMachine)
        return AAPLLoadStateInitial;
    return _stateMachine.currentState;
}

- (void)setLoadingState:(NSString *)loadingState
{
    AAPLLoadableContentStateMachine *stateMachine = self.stateMachine;
    if (loadingState != stateMachine.currentState)
        stateMachine.currentState = loadingState;
}

- (void)beginLoading
{
    self.loadingComplete = NO;
    self.loadingState = (([self.loadingState isEqualToString:AAPLLoadStateInitial] || [self.loadingState isEqualToString:AAPLLoadStateLoadingContent]) ? AAPLLoadStateLoadingContent : AAPLLoadStateRefreshingContent);

    [self notifyWillLoadContent];
}

- (void)endLoadingWithState:(NSString *)state error:(NSError *)error update:(dispatch_block_t)update
{
    self.loadingError = error;
    self.loadingState = state;

    if (self.shouldDisplayPlaceholder) {
        if (update)
            [self enqueuePendingUpdateBlock:update];
    }
    else {
        [self notifyBatchUpdate:^{
            // Run pending updates
            [self executePendingUpdates];
            if (update)
                update();
        }];
    }

    self.loadingComplete = YES;
    [self notifyContentLoadedWithError:error];
}

- (void)setNeedsLoadContent
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadContent) object:nil];
    [self performSelector:@selector(loadContent) withObject:nil afterDelay:0];
}

- (void)resetContent
{
    _stateMachine = nil;
    // Content has been reset, if we're loading something, chances are we don't need it.
    self.loadingInstance.current = NO;
}

- (void)loadContent
{
    // To be implemented by subclasses…
}

- (void)loadContentWithBlock:(AAPLLoadingBlock)block
{
    [self beginLoading];

    __weak typeof(&*self) weakself = self;

    AAPLLoading *loading = [AAPLLoading loadingWithCompletionHandler:^(NSString *newState, NSError *error, AAPLLoadingUpdateBlock update){
        if (!newState)
            return;

        [self endLoadingWithState:newState error:error update:^{
            AAPLDataSource *me = weakself;
            if (update && me)
                update(me);
        }];
    }];

    // Tell previous loading instance it's no longer current and remember this loading instance
    self.loadingInstance.current = NO;
    self.loadingInstance = loading;
    
    // Call the provided block to actually do the load
    block(loading);
}

- (void)whenLoaded:(dispatch_block_t)block
{
    __block int32_t complete = 0;

    [self aapl_addObserverForKeyPath:@"loadingComplete" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew withBlock:^(id obj, NSDictionary *change, id observer) {

        BOOL loadingComplete = [change[NSKeyValueChangeNewKey] boolValue];
        if (!loadingComplete)
            return;

        [self aapl_removeObserver:observer];

        // Already called the completion handler
        if (!OSAtomicCompareAndSwap32(0, 1, &complete))
            return;

        block();
    }];
}

- (void)stateWillChange
{
    // loadingState property isn't really Key Value Compliant, so let's begin a change notification
    [self willChangeValueForKey:@"loadingState"];
}

- (void)stateDidChange
{
    // loadingState property isn't really Key Value Compliant, so let's finish a change notification
    [self didChangeValueForKey:@"loadingState"];
}

- (void)didEnterLoadingState
{
    [self updatePlaceholder:self.placeholderView notifyVisibility:YES];
}

- (void)didEnterLoadedState
{
    [self updatePlaceholder:self.placeholderView notifyVisibility:YES];
}

- (void)didEnterNoContentState
{
    [self updatePlaceholder:self.placeholderView notifyVisibility:YES];
}

- (void)didEnterErrorState
{
    [self updatePlaceholder:self.placeholderView notifyVisibility:YES];
}

#pragma mark - UICollectionView metrics

- (AAPLLayoutSectionMetrics *)defaultMetrics
{
    if (_defaultMetrics)
        return _defaultMetrics;
    _defaultMetrics = [AAPLLayoutSectionMetrics defaultMetrics];
    return _defaultMetrics;
}

- (AAPLLayoutSectionMetrics *)metricsForSectionAtIndex:(NSInteger)sectionIndex
{
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];
    return _sectionMetrics[@(sectionIndex)];
}

- (void)setMetrics:(AAPLLayoutSectionMetrics *)metrics forSectionAtIndex:(NSInteger)sectionIndex
{
    NSParameterAssert(metrics != nil);
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];

    _sectionMetrics[@(sectionIndex)] = metrics;
}

- (AAPLLayoutSectionMetrics *)snapshotMetricsForSectionAtIndex:(NSInteger)sectionIndex
{
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];

    AAPLLayoutSectionMetrics *metrics = [self.defaultMetrics copy];
    [metrics applyValuesFromMetrics:_sectionMetrics[@(sectionIndex)]];

    // The root data source puts its headers into the special global section. Other data sources put theirs into their 0 section.
    BOOL rootDataSource = self.rootDataSource;
    if (rootDataSource && AAPLGlobalSection == sectionIndex) {
        metrics.headers = [NSArray arrayWithArray:_headers];
    }

    // We need to handle global headers and the placeholder view for section 0
    if (!sectionIndex) {
        NSMutableArray *headers = [NSMutableArray array];

        if (_headers && !rootDataSource)
            [headers addObjectsFromArray:_headers];

        metrics.hasPlaceholder = self.shouldDisplayPlaceholder;

        if (metrics.headers)
            [headers addObjectsFromArray:metrics.headers];

        metrics.headers = headers;
    }
    
    return metrics;
}

- (NSDictionary *)snapshotMetrics
{
    NSInteger numberOfSections = self.numberOfSections;
    NSMutableDictionary *metrics = [NSMutableDictionary dictionary];

    UIColor *defaultBackground = [UIColor whiteColor];

    AAPLLayoutSectionMetrics *globalMetrics = [self snapshotMetricsForSectionAtIndex:AAPLGlobalSection];
    if (!globalMetrics.backgroundColor)
        globalMetrics.backgroundColor = defaultBackground;
    metrics[@(AAPLGlobalSection)] = globalMetrics;

    for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
        AAPLLayoutSectionMetrics *sectionMetrics = [self snapshotMetricsForSectionAtIndex:sectionIndex];
        // assign default colors
        if (!sectionMetrics.backgroundColor)
            sectionMetrics.backgroundColor = defaultBackground;
        metrics[@(sectionIndex)] = sectionMetrics;
    }

    return metrics;
}

- (AAPLLayoutSupplementaryMetrics *)headerForKey:(NSString *)key
{
    return _headersByKey[key];
}

- (AAPLLayoutSupplementaryMetrics *)newHeaderForKey:(NSString *)key
{
    if (!_headers)
        _headers = [NSMutableArray array];
    if (!_headersByKey)
        _headersByKey = [NSMutableDictionary dictionary];

    NSAssert(!_headersByKey[key], @"Attempting to add a header for a key that already exists: %@", key);

    AAPLLayoutSupplementaryMetrics *header = [[AAPLLayoutSupplementaryMetrics alloc] init];
    _headersByKey[key] = header;
    [_headers addObject:header];
    return header;
}

- (void)replaceHeaderForKey:(NSString *)key withHeader:(AAPLLayoutSupplementaryMetrics *)header
{
    if (!_headers)
        _headers = [NSMutableArray array];
    if (!_headersByKey)
        _headersByKey = [NSMutableDictionary dictionary];

    AAPLLayoutSupplementaryMetrics *oldHeader = _headersByKey[key];
    NSAssert(oldHeader != nil, @"Attempting to replace a header that doesn't exist: key = %@", key);

    NSInteger headerIndex = [_headers indexOfObject:oldHeader];
    _headersByKey[key] = header;
    _headers[headerIndex] = header;
}

- (void)removeHeaderForKey:(NSString *)key
{
    if (!_headers)
        _headers = [NSMutableArray array];
    if (!_headersByKey)
        _headersByKey = [NSMutableDictionary dictionary];

    AAPLLayoutSupplementaryMetrics *oldHeader = _headersByKey[key];
    NSAssert(oldHeader != nil, @"Attempting to remove a header that doesn't exist: key = %@", key);

    [_headers removeObject:oldHeader];
    [_headersByKey removeObjectForKey:key];
}

- (AAPLLayoutSupplementaryMetrics *)newHeaderForSectionAtIndex:(NSInteger)sectionIndex
{
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];

    AAPLLayoutSectionMetrics *metrics = _sectionMetrics[@(sectionIndex)];
    if (!metrics) {
        metrics = [AAPLLayoutSectionMetrics metrics];
        _sectionMetrics[@(sectionIndex)] = metrics;
    }

    return [metrics newHeader];
}

- (AAPLLayoutSupplementaryMetrics *)newFooterForSectionAtIndex:(NSInteger)sectionIndex
{
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];

    AAPLLayoutSectionMetrics *metrics = _sectionMetrics[@(sectionIndex)];
    if (!metrics) {
        metrics = [AAPLLayoutSectionMetrics metrics];
        _sectionMetrics[@(sectionIndex)] = metrics;
    }

    return [metrics newFooter];
}

#pragma mark - Placeholder

- (BOOL)obscuredByPlaceholder
{
    if (self.shouldDisplayPlaceholder)
        return YES;

    if (!self.delegate)
        return NO;

    if (![self.delegate isKindOfClass:[AAPLDataSource class]])
        return NO;

    AAPLDataSource *dataSource = (AAPLDataSource *)self.delegate;
    return dataSource.obscuredByPlaceholder;
}

- (BOOL)shouldDisplayPlaceholder
{
    NSString *loadingState = self.loadingState;

    // If we're in the error state & have an error message or title
    if ([loadingState isEqualToString:AAPLLoadStateError] && (self.errorMessage || self.errorTitle))
        return YES;

    // Only display a placeholder when we're loading or have no content
    if (![loadingState isEqualToString:AAPLLoadStateLoadingContent] && ![loadingState isEqualToString:AAPLLoadStateNoContent])
        return NO;

    // Can't display the placeholder if both the title and message are missing
    if (!self.noContentMessage && !self.noContentTitle)
        return NO;

    return YES;
}

- (void)updatePlaceholder:(AAPLCollectionPlaceholderView *)placeholderView notifyVisibility:(BOOL)notify
{
    NSString *message;
    NSString *title;

    if (placeholderView) {
        NSString *loadingState = self.loadingState;
        if ([loadingState isEqualToString:AAPLLoadStateLoadingContent])
            [placeholderView showActivityIndicator:YES];
        else
            [placeholderView showActivityIndicator:NO];

        if ([loadingState isEqualToString:AAPLLoadStateNoContent]) {
            title = self.noContentTitle;
            message = self.noContentMessage;
            [placeholderView showPlaceholderWithTitle:title message:message image:self.noContentImage animated:YES];
        }
        else if ([loadingState isEqualToString:AAPLLoadStateError]) {
            title = self.errorTitle;
            message = self.errorMessage;
            [placeholderView showPlaceholderWithTitle:title message:message image:self.noContentImage animated:YES];
        }
        else
            [placeholderView hidePlaceholderAnimated:YES];
    }

    if (notify && (self.noContentTitle || self.noContentMessage || self.errorTitle || self.errorMessage))
        [self notifySectionsRefreshed:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.numberOfSections)]];
}

- (AAPLCollectionPlaceholderView *)dequeuePlaceholderViewForCollectionView:(UICollectionView *)collectionView atIndexPath:(NSIndexPath *)indexPath
{
    if (!_placeholderView)
        _placeholderView = [collectionView dequeueReusableSupplementaryViewOfKind:AAPLCollectionElementKindPlaceholder withReuseIdentifier:NSStringFromClass([AAPLCollectionPlaceholderView class]) forIndexPath:indexPath];
    [self updatePlaceholder:_placeholderView notifyVisibility:NO];
    return _placeholderView;
}

#pragma mark - Notification methods

- (void)executePendingUpdates
{
    AAPL_ASSERT_MAIN_THREAD;
    dispatch_block_t block = _pendingUpdateBlock;
    _pendingUpdateBlock = nil;
    if (block)
        block();
}

- (void)enqueuePendingUpdateBlock:(dispatch_block_t)block
{
    dispatch_block_t update;

    if (_pendingUpdateBlock) {
        dispatch_block_t oldPendingUpdate = _pendingUpdateBlock;
        update = ^{
            oldPendingUpdate();
            block();
        };
    }
    else
        update = block;

    self.pendingUpdateBlock = update;
}

- (void)notifyItemsInsertedAtIndexPaths:(NSArray *)insertedIndexPaths
{
    AAPL_ASSERT_MAIN_THREAD;
    if (self.shouldDisplayPlaceholder) {
        __weak typeof(&*self) weakself = self;
        [self enqueuePendingUpdateBlock:^{
            [weakself notifyItemsInsertedAtIndexPaths:insertedIndexPaths];
        }];
        return;
    }

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didInsertItemsAtIndexPaths:)]) {
        [delegate dataSource:self didInsertItemsAtIndexPaths:insertedIndexPaths];
    }
}

- (void)notifyItemsRemovedAtIndexPaths:(NSArray *)removedIndexPaths
{
    AAPL_ASSERT_MAIN_THREAD;
    if (self.shouldDisplayPlaceholder) {
        __weak typeof(&*self) weakself = self;
        [self enqueuePendingUpdateBlock:^{
            [weakself notifyItemsRemovedAtIndexPaths:removedIndexPaths];
        }];
        return;
    }

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didRemoveItemsAtIndexPaths:)]) {
        [delegate dataSource:self didRemoveItemsAtIndexPaths:removedIndexPaths];
    }
}

- (void)notifyItemsRefreshedAtIndexPaths:(NSArray *)refreshedIndexPaths
{
    AAPL_ASSERT_MAIN_THREAD;
    if (self.shouldDisplayPlaceholder) {
        __weak typeof(&*self) weakself = self;
        [self enqueuePendingUpdateBlock:^{
            [weakself notifyItemsRefreshedAtIndexPaths:refreshedIndexPaths];
        }];
        return;
    }

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didRefreshItemsAtIndexPaths:)]) {
        [delegate dataSource:self didRefreshItemsAtIndexPaths:refreshedIndexPaths];
    }
}

- (void)notifyItemMovedFromIndexPath:(NSIndexPath *)indexPath toIndexPaths:(NSIndexPath *)newIndexPath
{
    AAPL_ASSERT_MAIN_THREAD;
    if (self.shouldDisplayPlaceholder) {
        __weak typeof(&*self) weakself = self;
        [self enqueuePendingUpdateBlock:^{
            [weakself notifyItemMovedFromIndexPath:indexPath toIndexPaths:newIndexPath];
        }];
        return;
    }

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didMoveItemAtIndexPath:toIndexPath:)]) {
        [delegate dataSource:self didMoveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
    }
}

- (void)notifySectionsInserted:(NSIndexSet *)sections
{
    [self notifySectionsInserted:sections direction:AAPLDataSourceSectionOperationDirectionNone];
}

- (void)notifySectionsInserted:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    AAPL_ASSERT_MAIN_THREAD;

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didInsertSections:direction:)]) {
        [delegate dataSource:self didInsertSections:sections direction:direction];
    }
}

- (void)notifySectionsRemoved:(NSIndexSet *)sections
{
    [self notifySectionsRemoved:sections direction:AAPLDataSourceSectionOperationDirectionNone];
}

- (void)notifySectionsRemoved:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    AAPL_ASSERT_MAIN_THREAD;

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didRemoveSections:direction:)]) {
        [delegate dataSource:self didRemoveSections:sections direction:direction];
    }
}

- (void)notifySectionsRefreshed:(NSIndexSet *)sections
{
    AAPL_ASSERT_MAIN_THREAD;

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didRefreshSections:)]) {
        [delegate dataSource:self didRefreshSections:sections];
    }
}

- (void)notifySectionMovedFrom:(NSInteger)section to:(NSInteger)newSection
{
    [self notifySectionMovedFrom:section to:newSection direction:AAPLDataSourceSectionOperationDirectionNone];
}

- (void)notifySectionMovedFrom:(NSInteger)section to:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction
{
    AAPL_ASSERT_MAIN_THREAD;

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didMoveSection:toSection:direction:)]) {
        [delegate dataSource:self didMoveSection:section toSection:newSection direction:direction];
    }
}

- (void)notifyDidReloadData
{
    AAPL_ASSERT_MAIN_THREAD;

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSourceDidReloadData:)]) {
        [delegate dataSourceDidReloadData:self];
    }
}

- (void)notifyBatchUpdate:(dispatch_block_t)update
{
    [self notifyBatchUpdate:update complete:nil];
}

- (void)notifyBatchUpdate:(dispatch_block_t)update complete:(dispatch_block_t)complete
{
    AAPL_ASSERT_MAIN_THREAD;

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:performBatchUpdate:complete:)]) {
        [delegate dataSource:self performBatchUpdate:update complete:complete];
    }
    else {
        if (update) {
            update();
        }
        if (complete) {
            complete();
        }
    }
}

- (void)notifyContentLoadedWithError:(NSError *)error
{
    AAPL_ASSERT_MAIN_THREAD;
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didLoadContentWithError:)]) {
        [delegate dataSource:self didLoadContentWithError:error];
    }
}

- (void)notifyWillLoadContent
{
    AAPL_ASSERT_MAIN_THREAD;
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSourceWillLoadContent:)]) {
        [delegate dataSourceWillLoadContent:self];
    }
}

#pragma mark - UICollectionViewDataSource methods

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 0;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"Should be implemented by subclasses");
    return nil;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return self.numberOfSections;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:AAPLCollectionElementKindPlaceholder])
        return [self dequeuePlaceholderViewForCollectionView:collectionView atIndexPath:indexPath];

    NSInteger section;
    NSInteger item;
    AAPLDataSource *dataSource;

    if (indexPath.length == 1) {
        section = AAPLGlobalSection;
        item = [indexPath indexAtPosition:0];
        dataSource = self;
    }
    else {
        section = indexPath.section;
        item = indexPath.item;
        dataSource = [self dataSourceForSectionAtIndex:section];
    }

    AAPLLayoutSectionMetrics *sectionMetrics = [self snapshotMetricsForSectionAtIndex:section];
    AAPLLayoutSupplementaryMetrics *metrics;

    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        NSArray *headers = sectionMetrics.headers;
        metrics = (item < [headers count]) ? headers[item] : nil;
    }
    else if ([kind isEqualToString:UICollectionElementKindSectionFooter]) {
        NSArray *footers = sectionMetrics.footers;
        metrics = (item < [footers count]) ? footers[item] : nil;
    }

    if (!metrics)
        return nil;

    // Need to map the global index path to an index path relative to the target data source, because we're handling this method at the root of the data source tree. If I allowed subclasses to handle this, this wouldn't be necessary. But because of the way headers layer, it's more efficient to snapshot the section and find the metrics once.
    NSIndexPath *localIndexPath = [self localIndexPathForGlobalIndexPath:indexPath];
    UICollectionReusableView *view;
    if (metrics.createView)
        view = metrics.createView(collectionView, kind, metrics.reuseIdentifier, localIndexPath);
    else
        view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:metrics.reuseIdentifier forIndexPath:indexPath];

    NSAssert(view != nil, @"Unable to dequeue a reusable view with identifier %@", metrics.reuseIdentifier);
    if (!view)
        return nil;

    if (metrics.configureView)
        metrics.configureView(view, dataSource, localIndexPath);

    return view;
}

@end
