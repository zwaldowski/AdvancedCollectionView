/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of AAPLDataSource with multiple child data sources. Child data sources may have multiple sections. Load content messages will be sent to all child data sources.
 
  This file contains some classes used internally by the AAPLComposedDataSource to manage the mapping between external NSIndexPaths and child data source NSIndexPaths. Of particular interest is the AAPLComposedViewWrapper which proxies messages to UICollectionView.
 */

#import "AAPLDataSourceMapping.h"
#import "AAPLDataSource.h"
#import "AAPLShadowRegistrar.h"

#import <objc/runtime.h>

@protocol AAPLShadowRegistrarVending <NSObject>
@property (nonatomic, readonly) AAPLShadowRegistrar *shadowRegistrar;
@end


@interface AAPLDataSourceMapping ()

@property (nonatomic, strong) NSMutableDictionary *globalToLocalSections;
@property (nonatomic, strong) NSMutableDictionary *localToGlobalSections;
@property (nonatomic, readwrite) NSInteger numberOfSections;

@end

@implementation AAPLDataSourceMapping

- (instancetype)initWithDataSource:(AAPLDataSource *)dataSource
{
    self = [super init];
    if (!self)
        return nil;

    _dataSource = dataSource;
    _globalToLocalSections = [NSMutableDictionary dictionary];
    _localToGlobalSections = [NSMutableDictionary dictionary];
    return self;
}

- (nonnull instancetype)initWithDataSource:(AAPLDataSource *)dataSource globalSectionIndex:(NSInteger)sectionIndex
{
    self = [self initWithDataSource:dataSource];
    if (!self)
        return nil;

    [self updateMappingStartingAtGlobalSection:sectionIndex withBlock:^(NSInteger globalSectionIndex){}];
    return self;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Don't call %@.", @(__PRETTY_FUNCTION__)];
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    AAPLDataSourceMapping *result = [[[self class] allocWithZone:zone] init];
    result.dataSource = self.dataSource;
    result.globalToLocalSections = self.globalToLocalSections;
    result.localToGlobalSections = self.localToGlobalSections;

    return result;
}

- (NSInteger)localSectionForGlobalSection:(NSInteger)globalSection
{
    NSNumber *localSection = _globalToLocalSections[@(globalSection)];
    if (!localSection)
        return NSNotFound;
    return [localSection unsignedIntegerValue];
}

- (NSIndexSet *)localSectionsForGlobalSections:(NSIndexSet *)globalSections
{
    NSMutableIndexSet *localSections = [[NSMutableIndexSet alloc] init];

    [globalSections enumerateIndexesUsingBlock:^(NSUInteger globalSection, BOOL *stop) {
        NSNumber *localSection = _globalToLocalSections[@(globalSection)];
        if (!localSection)
            return;
        [localSections addIndex:localSection.unsignedIntegerValue];
    }];

    return localSections;
}

- (NSInteger)globalSectionForLocalSection:(NSInteger)localSection
{
    NSNumber *globalSection = _localToGlobalSections[@(localSection)];
    NSAssert(globalSection != nil,@"localSection %ld not found in localToGlobalSections:%@",(long)localSection,_localToGlobalSections);
    return [globalSection unsignedIntegerValue];
}

- (NSIndexSet *)globalSectionsForLocalSections:(NSIndexSet *)localSections
{
    NSMutableIndexSet *globalSections = [[NSMutableIndexSet alloc] init];

    [localSections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        NSNumber *globalSection = _localToGlobalSections[@(localSection)];
        NSAssert(globalSection != nil,@"localSection %ld not found in localToGlobalSections:%@",(long)localSection,_localToGlobalSections);
        [globalSections addIndex:globalSection.unsignedIntegerValue];
    }];

    return globalSections;
}

- (NSIndexPath *)localIndexPathForGlobalIndexPath:(NSIndexPath *)globalIndexPath
{
    NSInteger section = [self localSectionForGlobalSection:globalIndexPath.section];
    if (NSNotFound == section)
        return nil;
    return [NSIndexPath indexPathForItem:globalIndexPath.item inSection:section];
}

- (NSIndexPath *)globalIndexPathForLocalIndexPath:(NSIndexPath *)localIndexPath
{
    NSInteger section = [self globalSectionForLocalSection:localIndexPath.section];
    return [NSIndexPath indexPathForItem:localIndexPath.item inSection:section];
}

- (void)addMappingFromGlobalSection:(NSInteger)globalSection toLocalSection:(NSInteger)localSection
{
    NSNumber *globalNum = @(globalSection);
    NSNumber *localNum = @(localSection);
    NSAssert(_localToGlobalSections[localNum] == nil, @"collision while trying to add to a mapping");
    _globalToLocalSections[globalNum] = localNum;
    _localToGlobalSections[localNum] = globalNum;
}

- (void)updateMappingStartingAtGlobalSection:(NSInteger)globalSection withBlock:(void (^)(NSInteger globalSection))block
{
    _numberOfSections = _dataSource.numberOfSections;
    [_globalToLocalSections removeAllObjects];
    [_localToGlobalSections removeAllObjects];

    for (NSInteger localSection = 0; localSection<_numberOfSections; localSection++) {
        [self addMappingFromGlobalSection:globalSection toLocalSection:localSection];
        block(globalSection++);
    }
}

- (NSArray *)localIndexPathsForGlobalIndexPaths:(NSArray *)globalIndexPaths
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[globalIndexPaths count]];
    for (NSIndexPath *globalIndexPath in globalIndexPaths) {
        NSIndexPath *localIndexPath = [self localIndexPathForGlobalIndexPath:globalIndexPath];
        if (localIndexPath)
            [result addObject:localIndexPath];
    }

    return result;
}

- (NSArray *)globalIndexPathsForLocalIndexPaths:(NSArray *)localIndexPaths
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[localIndexPaths count]];
    for (NSIndexPath *localIndexPath in localIndexPaths)
        [result addObject:[self globalIndexPathForLocalIndexPath:localIndexPath]];

    return result;
}
@end



@interface AAPLCollectionViewWrapper ()
@property (nullable, nonatomic, strong) AAPLShadowRegistrar *shadowRegistrar;
@property (nonatomic, strong, readwrite) UICollectionView *collectionView;
@property (nullable, nonatomic, strong, readwrite) AAPLDataSourceMapping *mapping;
@end

@implementation AAPLCollectionViewWrapper

+ (UIView *)wrapperForCollectionView:(UICollectionView *)collectionView mapping:(AAPLDataSourceMapping *)mapping
{
    if (!collectionView)
        return nil;

    BOOL measuring = NO;

    if ([collectionView isKindOfClass:[AAPLCollectionViewWrapper class]])
        measuring = ((AAPLCollectionViewWrapper *)collectionView).measuring;

    return (UIView *)[[AAPLCollectionViewWrapper alloc] initWithCollectionView:collectionView mapping:mapping measuring:measuring];
}

+ (UIView *)wrapperForCollectionView:(UICollectionView *)collectionView mapping:(AAPLDataSourceMapping *)mapping measuring:(BOOL)measuring
{
    if (!collectionView)
        return nil;
    return (UIView *)[[AAPLCollectionViewWrapper alloc] initWithCollectionView:collectionView mapping:mapping measuring:measuring];
}

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView mapping:(AAPLDataSourceMapping *)mapping measuring:(BOOL)measuring
{
    self = [super init];
    if (!self)
        return nil;

    _collectionView = collectionView;
    _mapping = mapping;
    _measuring = measuring;

    // If the collection view's layout has a shadow registrar, let's grab it.
    UICollectionViewLayout *collectionViewLayout = collectionView.collectionViewLayout;
    if ([collectionViewLayout respondsToSelector:@selector(shadowRegistrar)]) {
        NSObject<AAPLShadowRegistrarVending> *shadowRegistrarVending = (NSObject<AAPLShadowRegistrarVending> *)collectionViewLayout;
        _shadowRegistrar = shadowRegistrarVending.shadowRegistrar;
    }

    return self;
}

#pragma mark - Forwarding to internal representation

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    return _collectionView;
}

+ (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)selector
{
    NSMethodSignature *signature = [super instanceMethodSignatureForSelector:selector];
    if (signature)
        return signature;

    return [[UICollectionView class] instanceMethodSignatureForSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    if (signature)
        return signature;
    else
        return [[self forwardingTargetForSelector:selector] methodSignatureForSelector:selector];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    BOOL responds = [super respondsToSelector:aSelector];
    if (!responds)
        responds = [[self forwardingTargetForSelector:aSelector] respondsToSelector:aSelector];
    return responds;
}

+ (BOOL)instancesRespondToSelector:(SEL)selector
{
    if (!selector)
        return NO;

    if (class_respondsToSelector(self, selector))
        return YES;

    if ([UICollectionView instancesRespondToSelector:selector])
        return YES;

    return NO;
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [_collectionView valueForKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    [_collectionView setValue:value forKey:key];
}

#pragma mark - UICollectionView registration methods

- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier
{
    [_shadowRegistrar registerClass:cellClass forCellWithReuseIdentifier:identifier];
    [_collectionView registerClass:cellClass forCellWithReuseIdentifier:identifier];
}

- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier
{
    [_shadowRegistrar registerNib:nib forCellWithReuseIdentifier:identifier];
    [_collectionView registerNib:nib forCellWithReuseIdentifier:identifier];
}

- (void)registerClass:(Class)viewClass forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier
{
    [_shadowRegistrar registerClass:viewClass forSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier];
    [_collectionView registerClass:viewClass forSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier];
}

- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier
{
    [_shadowRegistrar registerNib:nib forSupplementaryViewOfKind:kind withReuseIdentifier:identifier];
    [_collectionView registerNib:nib forSupplementaryViewOfKind:kind withReuseIdentifier:identifier];
}

#pragma mark - UICollectionView view dequeue methods

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath*)indexPath
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;

    if (_measuring && _shadowRegistrar)
        return [_shadowRegistrar dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:globalIndexPath collectionView:_collectionView];

    return [_collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:globalIndexPath];
}

- (id)dequeueReusableSupplementaryViewOfKind:(NSString*)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath*)indexPath
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;

    if (_measuring && _shadowRegistrar)
        return [_shadowRegistrar dequeueReusableSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier forIndexPath:globalIndexPath collectionView:_collectionView];

    return [_collectionView dequeueReusableSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier forIndexPath:globalIndexPath];
}

#pragma mark - UICollectionView helper methods

- (id)aapl_dequeueReusableCellWithClass:(Class)viewClass forIndexPath:(NSIndexPath *)indexPath
{
    NSString *reuseIdentifier = NSStringFromClass(viewClass);
    return [self dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
}

- (id)aapl_dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withClass:(Class)viewClass forIndexPath:(NSIndexPath *)indexPath
{
    NSString *reuseIdentifier = NSStringFromClass(viewClass);
    return [self dequeueReusableSupplementaryViewOfKind:elementKind withReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
}

#pragma mark - UICollectionView methods that accept index paths

- (NSIndexPath *)indexPathForCell:(id)cell
{
    NSIndexPath *globalIndexPath = [_collectionView indexPathForCell:cell];
    return _mapping ? [_mapping localIndexPathForGlobalIndexPath:globalIndexPath] : globalIndexPath;
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
    NSInteger globalSection = _mapping ? [_mapping globalSectionForLocalSection:section] : section;
    NSInteger globalNewSection = _mapping ? [_mapping globalSectionForLocalSection:newSection] : newSection;
    [_collectionView moveSection:globalSection toSection:globalNewSection];
}

// returns nil or an array of selected index paths
- (NSArray *)indexPathsForSelectedItems
{
    NSArray *globalIndexPaths = [_collectionView indexPathsForSelectedItems];
    if (!globalIndexPaths)
        return nil;
    return _mapping ? [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths] : globalIndexPaths;
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;
    [_collectionView selectItemAtIndexPath:globalIndexPath animated:animated scrollPosition:scrollPosition];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;
    [_collectionView deselectItemAtIndexPath:globalIndexPath animated:animated];
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
    NSInteger globalSection = _mapping ? [_mapping globalSectionForLocalSection:section] : section;
    return [_collectionView numberOfItemsInSection:globalSection];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;
    return [_collectionView layoutAttributesForItemAtIndexPath:globalIndexPath];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;
    return [_collectionView layoutAttributesForSupplementaryElementOfKind:kind atIndexPath:globalIndexPath];
}

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point
{
    NSIndexPath *globalIndexPath = [_collectionView indexPathForItemAtPoint:point];
    return _mapping ? [_mapping localIndexPathForGlobalIndexPath:globalIndexPath] : globalIndexPath;
}

- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;
    return [_collectionView cellForItemAtIndexPath:globalIndexPath];
}

- (NSArray *)indexPathsForVisibleItems
{
    NSArray *globalIndexPaths = [_collectionView indexPathsForVisibleItems];
    if (![globalIndexPaths count])
        return nil;

    return _mapping ? [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths] : globalIndexPaths;
}

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;
    [_collectionView scrollToItemAtIndexPath:globalIndexPath atScrollPosition:scrollPosition animated:animated];
}

- (void)insertSections:(NSIndexSet *)sections
{
    NSIndexSet *globalSections = _mapping ? [_mapping globalSectionsForLocalSections:sections] : sections;
    [_collectionView insertSections:globalSections];
}

- (void)deleteSections:(NSIndexSet *)sections
{
    NSIndexSet *globalSections = _mapping ? [_mapping globalSectionsForLocalSections:sections] : sections;
    [_collectionView deleteSections:globalSections];
}

- (void)reloadSections:(NSIndexSet *)sections
{
    NSIndexSet *globalSections = _mapping ? [_mapping globalSectionsForLocalSections:sections] : sections;
    [_collectionView reloadSections:globalSections];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSArray *globalIndexPaths = _mapping ? [_mapping globalIndexPathsForLocalIndexPaths:indexPaths] : indexPaths;
    [_collectionView insertItemsAtIndexPaths:globalIndexPaths];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSArray *globalIndexPaths = _mapping ? [_mapping globalIndexPathsForLocalIndexPaths:indexPaths] : indexPaths;
    [_collectionView deleteItemsAtIndexPaths:globalIndexPaths];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSArray *globalIndexPaths = _mapping ? [_mapping globalIndexPathsForLocalIndexPaths:indexPaths] : indexPaths;
    [_collectionView reloadItemsAtIndexPaths:globalIndexPaths];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;
    NSIndexPath *globalNewIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:newIndexPath] : newIndexPath;

    [_collectionView moveItemAtIndexPath:globalIndexPath toIndexPath:globalNewIndexPath];
}

- (UICollectionReusableView *)supplementaryViewForElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;
    return [_collectionView supplementaryViewForElementKind:elementKind atIndexPath:globalIndexPath];
}

- (NSArray *)indexPathsForVisibleSupplementaryElementsOfKind:(NSString *)elementKind
{
    NSArray *globalIndexPaths = [_collectionView indexPathsForVisibleSupplementaryElementsOfKind:elementKind];
    NSArray *localIndexPaths = _mapping ? [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths] : globalIndexPaths;
    return localIndexPaths;
}

- (BOOL)beginInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *globalIndexPath = _mapping ? [_mapping globalIndexPathForLocalIndexPath:indexPath] : indexPath;
    return [_collectionView beginInteractiveMovementForItemAtIndexPath:globalIndexPath];
}

@end
