/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of AAPLDataSource with multiple child data sources. Child data sources may have multiple sections. Load content messages will be sent to all child data sources.
 
  This file contains some classes used internally by the AAPLComposedDataSource to manage the mapping between external NSIndexPaths and child data source NSIndexPaths. Of particular interest is the AAPLComposedViewWrapper which proxies messages to UICollectionView.
  
 */

#import "AAPLComposedDataSource_Private.h"
@import ObjectiveC.runtime;

@interface AAPLComposedMapping ()

@property (nonatomic, retain) NSMutableDictionary *globalToLocalSections;
@property (nonatomic, retain) NSMutableDictionary *localToGlobalSections;

@end

@implementation AAPLComposedMapping

- (instancetype)init
{
    return [self initWithDataSource:nil];
}

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

- (id)copyWithZone:(NSZone *)zone
{
    AAPLComposedMapping *result = [[[self class] allocWithZone:zone] init];
    result.dataSource = self.dataSource;
    result.globalToLocalSections = self.globalToLocalSections;
    result.localToGlobalSections = self.localToGlobalSections;

    return result;
}

- (NSUInteger)localSectionForGlobalSection:(NSUInteger)globalSection
{
    NSNumber *localSection = _globalToLocalSections[@(globalSection)];
    NSAssert(localSection != nil,@"globalSection %ld not found in globalToLocalSections: %@",(long)globalSection,_globalToLocalSections);
    return [localSection unsignedIntegerValue];
}

- (NSUInteger)globalSectionForLocalSection:(NSUInteger)localSection
{
    NSNumber *globalSection = _localToGlobalSections[@(localSection)];
    NSAssert(globalSection != nil,@"localSection %ld not found in localToGlobalSections:%@",(long)localSection,_localToGlobalSections);
    return [globalSection unsignedIntegerValue];
}

- (NSIndexPath *)localIndexPathForGlobalIndexPath:(NSIndexPath *)globalIndexPath
{
    NSUInteger section = [self localSectionForGlobalSection:globalIndexPath.section];
    return [NSIndexPath indexPathForItem:globalIndexPath.item inSection:section];
}

- (NSIndexPath *)globalIndexPathForLocalIndexPath:(NSIndexPath *)localIndexPath
{
    NSUInteger section = [self globalSectionForLocalSection:localIndexPath.section];
    return [NSIndexPath indexPathForItem:localIndexPath.item inSection:section];
}

- (void)addMappingFromGlobalSection:(NSUInteger)globalSection toLocalSection:(NSUInteger)localSection
{
    NSNumber *globalNum = @(globalSection);
    NSNumber *localNum = @(localSection);
    NSAssert(_localToGlobalSections[localNum] == nil, @"collision while trying to add to a mapping");
    _globalToLocalSections[globalNum] = localNum;
    _localToGlobalSections[localNum] = globalNum;
}

- (NSUInteger)updateMappingsStartingWithGlobalSection:(NSUInteger)globalSection
{
    _sectionCount = _dataSource.numberOfSections;
    [_globalToLocalSections removeAllObjects];
    [_localToGlobalSections removeAllObjects];

    for (NSUInteger localSection = 0; localSection<_sectionCount; localSection++)
        [self addMappingFromGlobalSection:globalSection++ toLocalSection:localSection];
    return globalSection;
}

- (NSArray *)localIndexPathsForGlobalIndexPaths:(NSArray *)globalIndexPaths
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[globalIndexPaths count]];
    for (NSIndexPath *globalIndexPath in globalIndexPaths)
        [result addObject:[self localIndexPathForGlobalIndexPath:globalIndexPath]];

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

@implementation AAPLComposedViewWrapper

- (instancetype)initWithCollectionView:(UICollectionView *)view mapping:(AAPLComposedMapping *)mapping
{
    self = [super init];
    if (!self) { return nil; }
    _wrappedView = view;
    _mapping = mapping;
    return self;
}

#pragma mark - Forwarding to internal representation

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    return _wrappedView;
}

+ (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)selector
{
    return [super instanceMethodSignatureForSelector:selector] ?: [UICollectionView instanceMethodSignatureForSelector:selector];
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
    return [self.wrappedView valueForKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    [self.wrappedView setValue:value forKey:key];
}

#pragma mark - UICollectionView common methods

- (NSIndexPath *)indexPathForCell:(UICollectionViewCell *)cell
{
    NSIndexPath *globalIndexPath = [self.wrappedView indexPathForCell:cell];

    return [_mapping localIndexPathForGlobalIndexPath:globalIndexPath];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    NSUInteger globalNewSection = [_mapping globalSectionForLocalSection:newSection];

    [self.wrappedView moveSection:globalSection toSection:globalNewSection];
}

#pragma mark - UICollectionView methods that accept index paths

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath*)indexPath
{
    return [self.wrappedView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

- (id)dequeueReusableSupplementaryViewOfKind:(NSString*)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath*)indexPath
{
    return [self.wrappedView dequeueReusableSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier forIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

// returns nil or an array of selected index paths
- (NSArray *)indexPathsForSelectedItems
{
    NSArray *globalIndexPaths = [self.wrappedView indexPathsForSelectedItems];
    if (!globalIndexPaths)
        return nil;
    return [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths];
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition
{
    [self.wrappedView selectItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath] animated:animated scrollPosition:scrollPosition];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    [self.wrappedView deselectItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath] animated:animated];
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    return [self.wrappedView numberOfItemsInSection:globalSection];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.wrappedView layoutAttributesForItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    return [self.wrappedView layoutAttributesForSupplementaryElementOfKind:kind atIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point
{
    NSIndexPath *globalIndexPath = [self.wrappedView indexPathForItemAtPoint:point];
    return [_mapping localIndexPathForGlobalIndexPath:globalIndexPath];
}

- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.wrappedView cellForItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

- (NSArray *)indexPathsForVisibleItems
{
    NSArray *globalIndexPaths = [self.wrappedView indexPathsForVisibleItems];
    if (![globalIndexPaths count])
        return nil;

    return [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths];
}

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    [self.wrappedView scrollToItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath] atScrollPosition:scrollPosition animated:animated];
}

- (void)insertSections:(NSIndexSet *)sections
{
    NSMutableIndexSet *globalSections = [[NSMutableIndexSet alloc] init];

    [sections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        NSUInteger globalSection = [self.mapping globalSectionForLocalSection:localSection];
        [globalSections addIndex:globalSection];
    }];

    [self.wrappedView insertSections:sections];
}

- (void)deleteSections:(NSIndexSet *)sections
{
    NSMutableIndexSet *globalSections = [[NSMutableIndexSet alloc] init];

    [sections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        NSUInteger globalSection = [self.mapping globalSectionForLocalSection:localSection];
        [globalSections addIndex:globalSection];
    }];

    [self.wrappedView deleteSections:sections];
}

- (void)reloadSections:(NSIndexSet *)sections
{
    NSMutableIndexSet *globalSections = [[NSMutableIndexSet alloc] init];

    [sections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        NSUInteger globalSection = [self.mapping globalSectionForLocalSection:localSection];
        [globalSections addIndex:globalSection];
    }];

    [self.wrappedView reloadSections:sections];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSMutableArray *globalIndexPaths = [NSMutableArray arrayWithCapacity:[indexPaths count]];
    for (NSIndexPath *localIndexPath in indexPaths) {
        NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:localIndexPath];
        [globalIndexPaths addObject:globalIndexPath];
    }

    [self.wrappedView insertItemsAtIndexPaths:globalIndexPaths];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSMutableArray *globalIndexPaths = [NSMutableArray arrayWithCapacity:[indexPaths count]];
    for (NSIndexPath *localIndexPath in indexPaths) {
        NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:localIndexPath];
        [globalIndexPaths addObject:globalIndexPath];
    }

    [self.wrappedView deleteItemsAtIndexPaths:globalIndexPaths];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSMutableArray *globalIndexPaths = [NSMutableArray arrayWithCapacity:[indexPaths count]];
    for (NSIndexPath *localIndexPath in indexPaths) {
        NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:localIndexPath];
        [globalIndexPaths addObject:globalIndexPath];
    }

    [self.wrappedView reloadItemsAtIndexPaths:globalIndexPaths];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    [self.wrappedView moveItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath] toIndexPath:[_mapping globalIndexPathForLocalIndexPath:newIndexPath]];
}

@end
