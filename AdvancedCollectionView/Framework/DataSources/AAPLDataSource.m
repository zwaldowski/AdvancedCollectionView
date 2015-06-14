/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The base data source class.
 */

#import "AAPLDataSource_Private.h"
#import "AAPLLayoutMetrics_Private.h"

#import "AAPLPlaceholderView.h"
#import "AAPLCollectionViewCell.h"

#import <libkern/OSAtomic.h>

#import "AAPLDataSourceMetrics_Private.h"
#import "AAPLDebug.h"

static void *AAPLPerformUpdateQueueSpecificKey = "AAPLPerformUpdateQueueSpecificKey";

#define AAPL_ASSERT_MAIN_THREAD NSAssert([NSThread isMainThread], @"This method must be called on the main thread")

@implementation AAPLDataSourcePlaceholder

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image activityIndicator:(BOOL)activityIndicator
{
    NSParameterAssert(title != nil || message != nil || activityIndicator);

    self = [super init];
    if (!self)
        return nil;

    _title = [title copy];
    _message = [message copy];
    _image = image;
    _activityIndicator = activityIndicator;
    return self;
}

+ (instancetype)placeholderWithActivityIndicator
{
    return [[self alloc] initWithTitle:nil message:nil image:nil activityIndicator:YES];
}

+ (instancetype)placeholderWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image
{
    return [[self alloc] initWithTitle:title message:message image:image activityIndicator:NO];
}

- (id)copyWithZone:(NSZone *)zone
{
    AAPLDataSourcePlaceholder *copy = [[self.class alloc] initWithTitle:self.title message:self.message image:self.image activityIndicator:self.activityIndicator];
    return copy;
}

@end


@interface AAPLLoadingProgress()
@property (nonatomic, readwrite, getter = isCancelled) BOOL cancelled;
@end


@interface AAPLDataSource () <AAPLStateMachineDelegate>
@property (nonatomic, strong) NSMutableDictionary *sectionMetrics;
@property (nonatomic, strong) NSMutableArray *headers;
@property (nonatomic, strong) NSMutableDictionary *headersByKey;
@property (nonatomic, strong) AAPLLoadableContentStateMachine *stateMachine;
@property (nonatomic, copy) dispatch_block_t pendingUpdateBlock;
/// Chained completion handlers added externally via -whenLoaded:
@property (nonatomic, copy) dispatch_block_t loadingCompletionBlock;
@property (nonatomic, weak) AAPLLoadingProgress *loadingProgress;
@property (nonatomic, copy) AAPLDataSourcePlaceholder *placeholder;
@property (nonatomic) BOOL resettingContent;
@end

@implementation AAPLDataSource
@synthesize loadingError = _loadingError;

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _defaultMetrics = [[AAPLDataSourceSectionMetrics alloc] init];
    _allowsSelection = YES;
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

- (NSArray *)primaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return @[];
}

- (NSArray *)secondaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return @[];
}

- (NSInteger)numberOfSections
{
    return 1;
}

- (NSInteger)numberOfItemsInSection:(NSInteger)sectionIndex
{
    return 0;
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    NSInteger numberOfSections = self.numberOfSections;

    AAPLDataSourceSectionMetrics *globalMetrics = [self snapshotMetricsForSectionAtIndex:AAPLGlobalSectionIndex];
    for (AAPLSupplementaryItem* headerMetrics in globalMetrics.headers)
        [collectionView registerClass:headerMetrics.supplementaryViewClass forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:headerMetrics.reuseIdentifier];

    for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
        AAPLDataSourceSectionMetrics *metrics = [self snapshotMetricsForSectionAtIndex:sectionIndex];

        for (AAPLSupplementaryItem* headerMetrics in metrics.headers)
            [collectionView registerClass:headerMetrics.supplementaryViewClass forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:headerMetrics.reuseIdentifier];
        for (AAPLSupplementaryItem* footerMetrics in metrics.footers)
            [collectionView registerClass:footerMetrics.supplementaryViewClass forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:footerMetrics.reuseIdentifier];
    }

    [collectionView registerClass:[AAPLCollectionPlaceholderView class] forSupplementaryViewOfKind:AAPLCollectionElementKindPlaceholder withReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLCollectionPlaceholderView)];
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

- (void)endLoadingContentWithState:(NSString *)state error:(NSError *)error update:(dispatch_block_t)update
{
    self.loadingError = error;
    self.loadingState = state;

    dispatch_block_t pendingUpdates = _pendingUpdateBlock;
    _pendingUpdateBlock = nil;

    [self performUpdate:^{
        if (pendingUpdates)
            pendingUpdates();
        if (update)
            update();
    }];

    [self notifyContentLoadedWithError:error];
}

- (void)setNeedsLoadContent
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadContent) object:nil];
    [self performSelector:@selector(loadContent) withObject:nil afterDelay:0];
}

- (void)resetContent
{
    _resettingContent = YES;
    // This ONLY works because the resettingContent flag is set to YES. This will be checked in -missingTransitionFromState:toState: to decide whether to allow the transition.
    self.loadingState = AAPLLoadStateInitial;
    _resettingContent = NO;

    // Content has been reset, if we're loading something, chances are we don't need it.
    self.loadingProgress.cancelled = YES;
}

- (void)loadContent
{
    NSString *loadingState = self.loadingState;
    self.loadingState = (([loadingState isEqualToString:AAPLLoadStateInitial] || [loadingState isEqualToString:AAPLLoadStateLoadingContent]) ? AAPLLoadStateLoadingContent : AAPLLoadStateRefreshingContent);

    [self notifyWillLoadContent];

    __weak typeof(&*self) weakself = self;

    AAPLLoadingProgress *loadingProgress = [AAPLLoadingProgress loadingProgressWithCompletionHandler:^(NSString *newState, NSError *error, AAPLLoadingUpdateBlock update){
        // The only time newState will be nil is if the progress was cancelled.
        if (!newState)
            return;

        [self endLoadingContentWithState:newState error:error update:^{
            AAPLDataSource *me = weakself;
            if (update && me)
                update(me);
        }];
    }];

    // Tell previous loading instance it's no longer current and remember this loading instance
    self.loadingProgress.cancelled = YES;
    self.loadingProgress = loadingProgress;

    [self beginLoadingContentWithProgress:loadingProgress];
}

- (void)beginLoadingContentWithProgress:(AAPLLoadingProgress *)progress
{
    [self loadContentWithProgress:progress];
}

- (void)loadContentWithProgress:(AAPLLoadingProgress *)progress
{
    // This default implementation just signals that the load completed.
    [progress done];
}

- (void)whenLoaded:(dispatch_block_t)block
{
    __block int32_t complete = 0;

    dispatch_block_t oldLoadingCompleteBlock = self.loadingCompletionBlock;

    self.loadingCompletionBlock = ^{
        // Already called the completion handler
        if (!OSAtomicCompareAndSwap32(0, 1, &complete))
            return;

        // Call the previous completion block if there was one.
        if (oldLoadingCompleteBlock)
            oldLoadingCompleteBlock();

        block();
    };
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
    [self presentActivityIndicatorForSections:nil];
}

- (void)didExitLoadingState
{
    [self dismissPlaceholderForSections:nil];
}

- (void)didEnterNoContentState
{
    if (self.noContentPlaceholder)
        [self presentPlaceholder:self.noContentPlaceholder forSections:nil];
}

- (void)didEnterErrorState
{
    if (self.errorPlaceholder)
        [self presentPlaceholder:self.errorPlaceholder forSections:nil];
}

- (void)didExitErrorState
{
    if (self.errorPlaceholder)
        [self dismissPlaceholderForSections:nil];
}

- (void)didExitNoContentState
{
    if (self.noContentPlaceholder)
        [self dismissPlaceholderForSections:nil];
}

- (NSString *)missingTransitionFromState:(NSString *)fromState toState:(NSString *)toState
{
    if (!_resettingContent)
        return nil;

    if ([AAPLLoadStateInitial isEqualToString:toState])
        return toState;

    // All other cases fail
    return nil;
}

#pragma mark - UICollectionView metrics

- (AAPLSectionMetrics *)defaultMetrics
{
    if (_defaultMetrics)
        return _defaultMetrics;
    _defaultMetrics = [AAPLDataSourceSectionMetrics defaultMetrics];
    return _defaultMetrics;
}

- (AAPLSectionMetrics *)globalMetrics
{
    AAPLDataSourceSectionMetrics *globalMetrics = _sectionMetrics[@(AAPLGlobalSectionIndex)];
    if (globalMetrics)
        return globalMetrics;
    globalMetrics = [AAPLDataSourceSectionMetrics metrics];
    _sectionMetrics[@(AAPLGlobalSectionIndex)] = globalMetrics;
    return globalMetrics;
}

- (void)setGlobalMetrics:(AAPLSectionMetrics *)globalMetrics
{
    if (globalMetrics)
        _sectionMetrics[@(AAPLGlobalSectionIndex)] = globalMetrics;
    else
        [_sectionMetrics removeObjectForKey:@(AAPLGlobalSectionIndex)];
}

- (AAPLSectionMetrics *)metricsForSectionAtIndex:(NSInteger)sectionIndex
{
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];
    return _sectionMetrics[@(sectionIndex)];
}

- (void)setMetrics:(AAPLSectionMetrics *)metrics forSectionAtIndex:(NSInteger)sectionIndex
{
    NSParameterAssert(metrics != nil);
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];

    _sectionMetrics[@(sectionIndex)] = metrics;
}

- (NSInteger)numberOfHeadersInSectionAtIndex:(NSInteger)sectionIndex includeChildDataSouces:(BOOL)includeChildDataSources
{
    BOOL rootDataSource = self.rootDataSource;

    if (AAPLGlobalSectionIndex == sectionIndex && rootDataSource)
        return _headers.count;

    AAPLDataSourceSectionMetrics *defaultMetrics = (AAPLDataSourceSectionMetrics *)self.defaultMetrics;
    NSInteger numberOfHeaders = defaultMetrics.headers.count;

    if (!sectionIndex && !rootDataSource)
        numberOfHeaders += _headers.count;

    AAPLDataSourceSectionMetrics *sectionMetrics = _sectionMetrics[@(sectionIndex)];
    numberOfHeaders += sectionMetrics.headers.count;

    return numberOfHeaders;
}

- (NSInteger)numberOfFootersInSectionAtIndex:(NSInteger)sectionIndex includeChildDataSouces:(BOOL)includeChildDataSources
{
    BOOL rootDataSource = self.rootDataSource;

    if (AAPLGlobalSectionIndex == sectionIndex && rootDataSource)
        return 0;

    AAPLDataSourceSectionMetrics *defaultMetrics = (AAPLDataSourceSectionMetrics *)self.defaultMetrics;
    NSInteger numberOfFooters = defaultMetrics.footers.count;

#if 0
    // We don't have any global footers yet
    if (!sectionIndex && !rootDataSource)
        numberOfFooters += 0;
#endif

    AAPLDataSourceSectionMetrics *sectionMetrics = _sectionMetrics[@(sectionIndex)];
    numberOfFooters += sectionMetrics.footers.count;

    return numberOfFooters;
}

- (NSArray *)indexPathsForSupplementaryItem:(AAPLSupplementaryItem *)supplementaryItem header:(BOOL)header
{
    NSParameterAssert(supplementaryItem != nil);

    BOOL rootDataSource = self.rootDataSource;
    NSInteger numberOfSections = self.numberOfSections;
    __block NSInteger itemIndex;

    AAPLDataSourceSectionMetrics *defaultMetrics = (AAPLDataSourceSectionMetrics *)self.defaultMetrics;

    if (header) {
        itemIndex = [_headers indexOfObject:supplementaryItem];
        if (NSNotFound != itemIndex) {
            NSIndexPath *indexPath = rootDataSource ? [NSIndexPath indexPathWithIndex:itemIndex] : [NSIndexPath indexPathForItem:itemIndex inSection:0];
            return @[indexPath];
        }

        NSInteger numberOfGlobalHeaders = (NSInteger)_headers.count;

        itemIndex = [defaultMetrics.headers indexOfObject:supplementaryItem];
        if (NSNotFound != itemIndex) {
            NSMutableArray *result = [NSMutableArray array];

            // When the header is found in the default metrics, we need to create one NSIndexPath for each section
            for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
                NSInteger headerIndex = itemIndex;
                if (!sectionIndex && !rootDataSource)
                    headerIndex += numberOfGlobalHeaders;

                [result addObject:[NSIndexPath indexPathForItem:headerIndex inSection:sectionIndex]];
            }

            return [NSArray arrayWithArray:result];
        }

        NSInteger numberOfDefaultHeaders = (NSInteger)defaultMetrics.headers.count;

        __block NSIndexPath *result = nil;

        // If the supplementary metrics exist, it's in one of the section metrics. However, it **might** simply not exist.
        [_sectionMetrics enumerateKeysAndObjectsUsingBlock:^(NSNumber *sectionNumber, AAPLDataSourceSectionMetrics *sectionMetrics, BOOL *stop) {
            NSInteger sectionIndex = [sectionNumber integerValue];
            itemIndex = [sectionMetrics.headers indexOfObject:supplementaryItem];

            if (NSNotFound == itemIndex)
                return;

            NSInteger headerIndex = numberOfDefaultHeaders + itemIndex;
            if (!sectionIndex && !rootDataSource)
                headerIndex += numberOfGlobalHeaders;

            result = [NSIndexPath indexPathForItem:headerIndex inSection:sectionIndex];
            *stop = YES;
        }];

        if (result)
            return @[result];
        else
            return @[];
    }
    else {
        NSInteger numberOfGlobalFooters = 0;

        itemIndex = [defaultMetrics.footers indexOfObject:supplementaryItem];
        if (NSNotFound != itemIndex) {
            NSMutableArray *result = [NSMutableArray array];

            // When the header is found in the default metrics, we need to create one NSIndexPath for each section
            for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
                NSInteger footerIndex = itemIndex;
                if (!sectionIndex && !rootDataSource)
                    footerIndex += numberOfGlobalFooters;

                [result addObject:[NSIndexPath indexPathForItem:footerIndex inSection:sectionIndex]];
            }

            return [NSArray arrayWithArray:result];
        }

        NSInteger numberOfDefaultFooters = (NSInteger)defaultMetrics.footers.count;

        __block NSIndexPath *result = nil;

        // If the supplementary metrics exist, it's in one of the section metrics. However, it **might** simply not exist.
        [_sectionMetrics enumerateKeysAndObjectsUsingBlock:^(NSNumber *sectionNumber, AAPLDataSourceSectionMetrics *sectionMetrics, BOOL *stop) {
            NSInteger sectionIndex = [sectionNumber integerValue];
            itemIndex = [sectionMetrics.footers indexOfObject:supplementaryItem];

            if (NSNotFound == itemIndex)
                return;

            NSInteger footerIndex = numberOfDefaultFooters + itemIndex;
            if (!sectionIndex && !rootDataSource)
                footerIndex += numberOfGlobalFooters;

            result = [NSIndexPath indexPathForItem:footerIndex inSection:sectionIndex];
            *stop = YES;
        }];

        if (result)
            return @[result];
        else
            return @[];
    }
}

- (void)findSupplementaryItemForHeader:(BOOL)header indexPath:(NSIndexPath *)indexPath usingBlock:(void(^)(AAPLDataSource *dataSource, NSIndexPath *localIndexPath, AAPLSupplementaryItem *supplementaryItem))block
{
    NSParameterAssert(block != nil);

    NSInteger sectionIndex = (indexPath.length > 1 ? indexPath.section : AAPLGlobalSectionIndex);
    NSInteger itemIndex = (indexPath.length > 1 ? indexPath.item : [indexPath indexAtPosition:0]);

    BOOL rootDataSource = self.rootDataSource;

    // We should only have the global section when we're also the root data source
    NSAssert(AAPLGlobalSectionIndex != sectionIndex || rootDataSource, @"Should only have a global section index when we're the root data source");

    if (header) {
        if (AAPLGlobalSectionIndex == sectionIndex && rootDataSource) {
            if (itemIndex < (NSInteger)_headers.count)
                block(self, indexPath, _headers[itemIndex]);
            return;
        }

        if (0 == sectionIndex && !rootDataSource) {
            if (itemIndex < (NSInteger)_headers.count)
                return block(self, indexPath, _headers[itemIndex]);

            // need to allow for the headers that were added from the "global" data source headers.
            itemIndex -= _headers.count;
        }

        // check for headers in the default metrics
        AAPLDataSourceSectionMetrics *defaultMetrics = (AAPLDataSourceSectionMetrics *)self.defaultMetrics;
        if (itemIndex < (NSInteger)defaultMetrics.headers.count)
            return block(self, [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex], defaultMetrics.headers[itemIndex]);

        itemIndex -= defaultMetrics.headers.count;

        AAPLDataSourceSectionMetrics *sectionMetrics = _sectionMetrics[@(sectionIndex)];
        if (itemIndex < (NSInteger)sectionMetrics.headers.count)
            return block(self, [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex], sectionMetrics.headers[itemIndex]);
    }
    else {
        // check for footers in the default metrics
        AAPLDataSourceSectionMetrics *defaultMetrics = (AAPLDataSourceSectionMetrics *)self.defaultMetrics;
        if (itemIndex < (NSInteger)defaultMetrics.footers.count)
            return block(self, [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex], defaultMetrics.footers[itemIndex]);

        itemIndex -= defaultMetrics.footers.count;

        // There's no equivalent to the headers by key (yet)
        AAPLDataSourceSectionMetrics *sectionMetrics = _sectionMetrics[@(sectionIndex)];
        if (itemIndex < (NSInteger)sectionMetrics.footers.count)
            return block(self, [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex], sectionMetrics.footers[itemIndex]);

    }
}

- (AAPLDataSourceSectionMetrics *)snapshotMetricsForSectionAtIndex:(NSInteger)sectionIndex
{
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];

    AAPLDataSourceSectionMetrics *metrics = [self.defaultMetrics copy];
    [metrics applyValuesFromMetrics:_sectionMetrics[@(sectionIndex)]];

    // The root data source puts its headers into the special global section. Other data sources put theirs into their 0 section.
    BOOL rootDataSource = self.rootDataSource;
    if (rootDataSource && AAPLGlobalSectionIndex == sectionIndex) {
        metrics.headers = [NSArray arrayWithArray:_headers];
    }

    // Stash the placeholder in the metrics. This is really only used so we can determine the range of the placeholders.
    metrics.placeholder = self.placeholder;

    // We need to handle global headers and the placeholder view for section 0
    if (!sectionIndex) {
        NSMutableArray *headers = [NSMutableArray array];

        if (_headers && !rootDataSource)
            [headers addObjectsFromArray:_headers];

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

    AAPLDataSourceSectionMetrics *globalMetrics = [self snapshotMetricsForSectionAtIndex:AAPLGlobalSectionIndex];
    metrics[@(AAPLGlobalSectionIndex)] = globalMetrics;

    for (NSInteger sectionIndex = 0; sectionIndex < numberOfSections; ++sectionIndex) {
        AAPLDataSourceSectionMetrics *sectionMetrics = [self snapshotMetricsForSectionAtIndex:sectionIndex];
        metrics[@(sectionIndex)] = sectionMetrics;
    }

    return metrics;
}

- (AAPLSupplementaryItem *)headerForKey:(NSString *)key
{
    return _headersByKey[key];
}

- (AAPLSupplementaryItem *)newHeaderForKey:(NSString *)key
{
    if (!_headers)
        _headers = [NSMutableArray array];
    if (!_headersByKey)
        _headersByKey = [NSMutableDictionary dictionary];

    NSAssert(!_headersByKey[key], @"Attempting to add a header for a key that already exists: %@", key);

    AAPLSupplementaryItem *header = [[AAPLSupplementaryItem alloc] initWithElementKind:UICollectionElementKindSectionHeader];
    _headersByKey[key] = header;
    [_headers addObject:header];
    return header;
}

- (void)replaceHeaderForKey:(NSString *)key withHeader:(AAPLSupplementaryItem *)header
{
    if (!_headers)
        _headers = [NSMutableArray array];
    if (!_headersByKey)
        _headersByKey = [NSMutableDictionary dictionary];

    AAPLSupplementaryItem *oldHeader = _headersByKey[key];
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

    AAPLSupplementaryItem *oldHeader = _headersByKey[key];
    NSAssert(oldHeader != nil, @"Attempting to remove a header that doesn't exist: key = %@", key);

    [_headers removeObject:oldHeader];
    [_headersByKey removeObjectForKey:key];
}

- (AAPLSupplementaryItem *)newSectionHeader
{
    AAPLDataSourceSectionMetrics *defaultMetrics = (AAPLDataSourceSectionMetrics *)self.defaultMetrics;
    AAPLDataSourceSupplementaryItem *header = (AAPLDataSourceSupplementaryItem *)[defaultMetrics newHeader];

    return header;
}

- (AAPLSupplementaryItem *)newSectionFooter
{
    AAPLDataSourceSectionMetrics *defaultMetrics = (AAPLDataSourceSectionMetrics *)self.defaultMetrics;
    AAPLDataSourceSupplementaryItem *footer = (AAPLDataSourceSupplementaryItem *)[defaultMetrics newFooter];

    return footer;
}

- (AAPLSupplementaryItem *)newHeaderForSectionAtIndex:(NSInteger)sectionIndex
{
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];

    AAPLDataSourceSectionMetrics *metrics = _sectionMetrics[@(sectionIndex)];
    if (!metrics) {
        metrics = [AAPLDataSourceSectionMetrics metrics];
        _sectionMetrics[@(sectionIndex)] = metrics;
    }

    return [metrics newHeader];
}

- (AAPLSupplementaryItem *)newFooterForSectionAtIndex:(NSInteger)sectionIndex
{
    if (!_sectionMetrics)
        _sectionMetrics = [NSMutableDictionary dictionary];

    AAPLDataSourceSectionMetrics *metrics = _sectionMetrics[@(sectionIndex)];
    if (!metrics) {
        metrics = [AAPLDataSourceSectionMetrics metrics];
        _sectionMetrics[@(sectionIndex)] = metrics;
    }

    return [metrics newFooter];
}

#pragma mark - Placeholder

- (BOOL)shouldShowActivityIndicator
{
    NSString *loadingState = self.loadingState;

    return (self.showsActivityIndicatorWhileRefreshingContent && [loadingState isEqualToString:AAPLLoadStateRefreshingContent]) || [loadingState isEqualToString:AAPLLoadStateLoadingContent];
}

- (BOOL)shouldShowPlaceholder
{
    return self.placeholder ? YES : NO;
}

- (void)presentActivityIndicatorForSections:(NSIndexSet *)sections
{
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if (![delegate respondsToSelector:@selector(dataSource:didPresentActivityIndicatorForSections:)])
        return;

    if (!sections)
        sections = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.numberOfSections)];

    [self internalPerformUpdate:^{
        if ([sections containsIndexesInRange:NSMakeRange(0, self.numberOfSections)])
            self.placeholder = [AAPLDataSourcePlaceholder placeholderWithActivityIndicator];

        // The data source can't do this itself, so the request is passed up the tree. Ultimately this will be handled by the collection view by passing it along to the layout.
        [delegate dataSource:self didPresentActivityIndicatorForSections:sections];
    }];
}

- (void)presentPlaceholder:(AAPLDataSourcePlaceholder *)placeholder forSections:(NSIndexSet *)sections
{
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if (![delegate respondsToSelector:@selector(dataSource:didPresentPlaceholderForSections:)])
        return;

    if (!sections)
        sections = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.numberOfSections)];

    [self internalPerformUpdate:^{
        if (placeholder && [sections containsIndexesInRange:NSMakeRange(0, self.numberOfSections)])
            self.placeholder = placeholder;

        // The data source can't do this itself, so the request is passed up the tree. Ultimately this will be handled by the collection view by passing it along to the layout.
        [delegate dataSource:self didPresentPlaceholderForSections:sections];
    }];
}

- (void)dismissPlaceholderForSections:(NSIndexSet *)sections
{
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if (![delegate respondsToSelector:@selector(dataSource:didDismissPlaceholderForSections:)])
        return;

    if (!sections)
        sections = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.numberOfSections)];

    [self internalPerformUpdate:^{
        // Clear the placeholder when the sections represents the entire range of sections in this data source.
        if ([sections containsIndexesInRange:NSMakeRange(0, self.numberOfSections)])
            self.placeholder = nil;

        // We need to pass this up the tree of data sources until it reaches the collection view, which will then pass it to the layout.
        [delegate dataSource:self didDismissPlaceholderForSections:sections];
    }];
}

- (void)updatePlaceholderView:(AAPLCollectionPlaceholderView *)placeholderView forSectionAtIndex:(NSInteger)sectionIndex
{
    NSString *message;
    NSString *title;
    UIImage *image;

    if (!placeholderView)
        return;

    // Handle loading and refreshing states
    if (self.shouldShowActivityIndicator) {
        [placeholderView showActivityIndicator:YES];
        [placeholderView hidePlaceholderAnimated:YES];
        return;
    }

    // For other states, start by turning off the activity indicator
    [placeholderView showActivityIndicator:NO];

    AAPLDataSourcePlaceholder *placeholder = self.placeholder;
    title = placeholder.title;
    message = placeholder.message;
    image = placeholder.image;

    if (title || message || image)
        [placeholderView showPlaceholderWithTitle:title message:message image:image animated:YES];
    else
        [placeholderView hidePlaceholderAnimated:YES];
}

- (AAPLCollectionPlaceholderView *)dequeuePlaceholderViewForCollectionView:(UICollectionView *)collectionView atIndexPath:(NSIndexPath *)indexPath
{
    AAPLCollectionPlaceholderView *placeholderView = [collectionView dequeueReusableSupplementaryViewOfKind:AAPLCollectionElementKindPlaceholder withReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLCollectionPlaceholderView) forIndexPath:indexPath];

    [self updatePlaceholderView:placeholderView forSectionAtIndex:indexPath.section];
    return placeholderView;
}

#pragma mark - Notification methods

- (void)didBecomeActive
{
    NSString *loadingState = self.loadingState;

    if ([loadingState isEqualToString:AAPLLoadStateInitial]) {
        [self setNeedsLoadContent];
        return;
    }

    if (self.shouldShowActivityIndicator) {
        [self presentActivityIndicatorForSections:nil];
        return;
    }

    // If there's a placeholder, we assume it needs to be re-presented. This means the placeholder ivar must be cleared when the placeholder is dismissed.
    if (self.placeholder)
        [self presentPlaceholder:self.placeholder forSections:nil];
}

- (void)willResignActive
{
    // We need to hang onto the placeholder, because dismiss clears it
    AAPLDataSourcePlaceholder *placeholder = self.placeholder;
    if (placeholder) {
        [self dismissPlaceholderForSections:nil];
        self.placeholder = placeholder;
    }
}

#if DEBUG
BOOL AAPLInDataSourceUpdate(AAPLDataSource *dataSource)
{
    // We don't care if there's no delegate.
    if (!dataSource.delegate)
        return YES;

    dispatch_queue_t main_queue = dispatch_get_main_queue();

    void *markerValue = dispatch_queue_get_specific(main_queue, AAPLPerformUpdateQueueSpecificKey);
    return markerValue != nil;
}
#endif

- (void)performUpdate:(dispatch_block_t)update
{
    [self performUpdate:update complete:nil];
}

- (void)performUpdate:(dispatch_block_t)block complete:(dispatch_block_t)completionHandler
{
    AAPL_ASSERT_MAIN_THREAD;

    // If this data source is loading, wait until we're done before we execute the update
    if ([self.loadingState isEqualToString:AAPLLoadStateLoadingContent]) {
        __weak typeof(&*self) weakself = self;
        [self enqueueUpdateBlock:^{
            [weakself performUpdate:block complete:completionHandler];
        }];
        return;
    }

    [self internalPerformUpdate:block complete:completionHandler];
}

- (void)internalPerformUpdate:(dispatch_block_t)block
{
    [self internalPerformUpdate:block complete:nil];
}

- (void)internalPerformUpdate:(dispatch_block_t)block complete:(dispatch_block_t)completionHandler
{
#if DEBUG
    dispatch_block_t updateBlock = ^{
        dispatch_queue_t main_queue = dispatch_get_main_queue();

        // Establish a marker that we're in an update block. This will be used by the AAPL_ASSERT_IN_DATASOURCE_UPDATE to ensure things will update correctly.
        void *originalValue = dispatch_queue_get_specific(main_queue, AAPLPerformUpdateQueueSpecificKey);
        if (!originalValue)
            dispatch_queue_set_specific(main_queue, AAPLPerformUpdateQueueSpecificKey, (__bridge void *)(self), NULL);

        if (block)
            block();

        if (!originalValue)
            dispatch_queue_set_specific(main_queue, AAPLPerformUpdateQueueSpecificKey, originalValue, NULL);
    };
#else
    dispatch_block_t updateBlock = block;
#endif

    // If our delegate our delegate can handle this for us, pass it up the tree
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if (delegate && [delegate respondsToSelector:@selector(dataSource:performBatchUpdate:complete:)])
        [delegate dataSource:self performBatchUpdate:updateBlock complete:completionHandler];
    else {
        if (updateBlock)
            updateBlock();
        if (completionHandler)
            completionHandler();
    }
}

- (void)enqueueUpdateBlock:(dispatch_block_t)block
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
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didInsertItemsAtIndexPaths:)]) {
        [delegate dataSource:self didInsertItemsAtIndexPaths:insertedIndexPaths];
    }
}

- (void)notifyItemsRemovedAtIndexPaths:(NSArray *)removedIndexPaths
{
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didRemoveItemsAtIndexPaths:)]) {
        [delegate dataSource:self didRemoveItemsAtIndexPaths:removedIndexPaths];
    }
}

- (void)notifyItemsRefreshedAtIndexPaths:(NSArray *)refreshedIndexPaths
{
    AAPL_ASSERT_MAIN_THREAD;
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didRefreshItemsAtIndexPaths:)]) {
        [delegate dataSource:self didRefreshItemsAtIndexPaths:refreshedIndexPaths];
    }
}

- (void)notifyItemMovedFromIndexPath:(NSIndexPath *)indexPath toIndexPaths:(NSIndexPath *)newIndexPath
{
    AAPL_ASSERT_MAIN_THREAD;
    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didMoveItemAtIndexPath:toIndexPath:)]) {
        [delegate dataSource:self didMoveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
    }
}

- (void)notifySectionsInserted:(NSIndexSet *)sections
{
    AAPL_ASSERT_MAIN_THREAD;

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
    AAPL_ASSERT_MAIN_THREAD;

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
    AAPL_ASSERT_MAIN_THREAD;

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

- (void)notifyContentLoadedWithError:(NSError *)error
{
    AAPL_ASSERT_MAIN_THREAD;

    dispatch_block_t loadingCompleteBlock = self.loadingCompletionBlock;
    self.loadingCompletionBlock = nil;
    if (loadingCompleteBlock)
        loadingCompleteBlock();

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

- (void)notifyContentUpdatedForHeader:(AAPLSupplementaryItem *)header
{
    NSArray *indexPaths = [self indexPathsForSupplementaryItem:header header:YES];

    [self notifyContentUpdatedForSupplementaryItem:header atIndexPaths:indexPaths header:YES];
}

- (void)notifyContentUpdatedForFooter:(AAPLSupplementaryItem *)footer
{
    NSArray *indexPaths = [self indexPathsForSupplementaryItem:footer header:NO];

    [self notifyContentUpdatedForSupplementaryItem:footer atIndexPaths:indexPaths header:NO];
}

- (void)notifyContentUpdatedForSupplementaryItem:(AAPLSupplementaryItem *)metrics atIndexPaths:(NSArray *)indexPaths header:(BOOL)header
{
    AAPL_ASSERT_MAIN_THREAD;

    id<AAPLDataSourceDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(dataSource:didUpdateSupplementaryItem:atIndexPaths:header:)])
        [delegate dataSource:self didUpdateSupplementaryItem:metrics atIndexPaths:indexPaths header:header];
}

#pragma mark - UICollectionViewDataSource methods

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    // When we're showing a placeholder, we have to lie to the collection view about the number of items we have. Otherwise, it will ask for layout attributes that we don't have.
    return self.placeholder ? 0 : [self numberOfItemsInSection:section];
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

    BOOL header;

    if ([kind isEqualToString:UICollectionElementKindSectionHeader])
        header = YES;
    else if ([kind isEqualToString:UICollectionElementKindSectionFooter])
        header = NO;
    else
        return nil;

    __block AAPLSupplementaryItem *metrics = nil;
    __block NSIndexPath *localIndexPath = nil;
    __block AAPLDataSource *dataSource = self;

    [self findSupplementaryItemForHeader:header indexPath:indexPath usingBlock:^(AAPLDataSource *foundDataSource, NSIndexPath *foundIndexPath, AAPLSupplementaryItem *foundMetrics) {
        dataSource = foundDataSource;
        localIndexPath = foundIndexPath;
        metrics = foundMetrics;
    }];
    
    NSAssert(metrics != nil, @"Couldn't find metrics for the supplementary view of kind %@ at indexPath %@", kind, AAPLStringFromNSIndexPath(indexPath));
    if (!metrics)
        return nil;
    
    UICollectionReusableView *view;
    view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:metrics.reuseIdentifier forIndexPath:indexPath];
    
    NSAssert(view != nil, @"Unable to dequeue a reusable view with identifier %@", metrics.reuseIdentifier);
    if (!view)
        return nil;
    
    if (metrics.configureView)
        metrics.configureView(view, dataSource, localIndexPath);
    
    return view;
}

@end
