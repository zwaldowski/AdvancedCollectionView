/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of AAPLDataSource with multiple child data sources. Child data sources may have multiple sections. Load content messages will be sent to all child data sources.
 
  This file contains some classes used internally by the AAPLComposedDataSource to manage the mapping between external NSIndexPaths and child data source NSIndexPaths. Of particular interest is the AAPLComposedViewWrapper which proxies messages to UICollectionView.
  
 */

#import "AAPLComposedDataSource_Private.h"
#import <objc/runtime.h>

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

+ (id)wrapperForView:(UIView *)view mapping:(AAPLComposedMapping *)mapping
{
    if (!view)
        return nil;
    return [[AAPLComposedViewWrapper alloc] initWithView:view mapping:mapping];
}

- (id)initWithView:(UIView *)view mapping:(AAPLComposedMapping *)mapping
{
    NSParameterAssert([view isKindOfClass:[UITableView class]] || [view isKindOfClass:[UICollectionView class]]);

    self = [super init];
    if (!self)
        return nil;

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
    NSMethodSignature *signature = [super instanceMethodSignatureForSelector:selector];
    if (signature)
        return signature;

    signature = [[UITableView class] instanceMethodSignatureForSelector:selector];
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

    if ([UITableView instancesRespondToSelector:selector])
        return YES;

    if ([UICollectionView instancesRespondToSelector:selector])
        return YES;

    return NO;
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [_wrappedView valueForKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    [_wrappedView setValue:value forKey:key];
}

#pragma mark - UITableView & UICollectionView common methods

- (NSIndexPath *)indexPathForCell:(id)cell
{
    NSIndexPath *globalIndexPath;

    if ([_wrappedView isKindOfClass:[UITableView class]])
        globalIndexPath = [(UITableView *)_wrappedView indexPathForCell:cell];
    else
        globalIndexPath = [(UICollectionView *)_wrappedView indexPathForCell:cell];

    return [_mapping localIndexPathForGlobalIndexPath:globalIndexPath];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    NSUInteger globalNewSection = [_mapping globalSectionForLocalSection:newSection];

    if ([_wrappedView isKindOfClass:[UITableView class]])
        [(UITableView *)_wrappedView moveSection:globalSection toSection:globalNewSection];
    else
        [(UICollectionView *)_wrappedView moveSection:globalSection toSection:globalNewSection];
}


#pragma mark - UITableView methods that accept index paths

- (NSInteger)numberOfSections
{
    return _mapping.sectionCount;
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    return [(UITableView *)_wrappedView numberOfRowsInSection:globalSection];
}

- (CGRect)rectForSection:(NSInteger)section
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    return [(UITableView *)_wrappedView rectForSection:globalSection];
}

- (CGRect)rectForHeaderInSection:(NSInteger)section
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    return [(UITableView *)_wrappedView rectForHeaderInSection:globalSection];
}

- (CGRect)rectForFooterInSection:(NSInteger)section
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    return [(UITableView *)_wrappedView rectForFooterInSection:globalSection];
}

- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:indexPath];
    return [(UITableView *)_wrappedView rectForRowAtIndexPath:globalIndexPath];
}

- (NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point
{
    NSIndexPath *globalIndexPath = [(UITableView *)_wrappedView indexPathForRowAtPoint:point];
    return [_mapping localIndexPathForGlobalIndexPath:globalIndexPath];
}

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect
{
    NSArray *globalIndexPaths = [(UITableView *)_wrappedView indexPathsForRowsInRect:rect];
    return [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths];
}

- (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:indexPath];
    return [(UITableView *)_wrappedView cellForRowAtIndexPath:globalIndexPath];
}

- (NSArray *)indexPathsForVisibleRows
{
    NSArray *globalIndexPaths = [(UITableView *)_wrappedView indexPathsForVisibleRows];
    return [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths];
}

- (UITableViewHeaderFooterView *)headerViewForSection:(NSInteger)section
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    return [(UITableView *)_wrappedView headerViewForSection:globalSection];
}

- (UITableViewHeaderFooterView *)footerViewForSection:(NSInteger)section
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    return [(UITableView *)_wrappedView footerViewForSection:globalSection];
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:indexPath];
    [(UITableView *)_wrappedView scrollToRowAtIndexPath:globalIndexPath atScrollPosition:scrollPosition animated:animated];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    NSMutableIndexSet *globalSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        [globalSections addIndex:[_mapping globalSectionForLocalSection:localSection]];
    }];
    [(UITableView *)_wrappedView insertSections:globalSections withRowAnimation:animation];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    NSMutableIndexSet *globalSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        [globalSections addIndex:[_mapping globalSectionForLocalSection:localSection]];
    }];
    [(UITableView *)_wrappedView deleteSections:globalSections withRowAnimation:animation];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    NSMutableIndexSet *globalSections = [NSMutableIndexSet indexSet];
    [sections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        [globalSections addIndex:[_mapping globalSectionForLocalSection:localSection]];
    }];
    [(UITableView *)_wrappedView reloadSections:globalSections withRowAnimation:animation];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    NSArray *globalIndexPaths = [_mapping globalIndexPathsForLocalIndexPaths:indexPaths];
    [(UITableView *)_wrappedView insertRowsAtIndexPaths:globalIndexPaths withRowAnimation:animation];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    NSArray *globalIndexPaths = [_mapping globalIndexPathsForLocalIndexPaths:indexPaths];
    [(UITableView *)_wrappedView deleteRowsAtIndexPaths:globalIndexPaths withRowAnimation:animation];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    NSArray *globalIndexPaths = [_mapping globalIndexPathsForLocalIndexPaths:indexPaths];
    [(UITableView *)_wrappedView reloadRowsAtIndexPaths:globalIndexPaths withRowAnimation:animation];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:indexPath];
    NSIndexPath *globalNewIndexPath = [_mapping globalIndexPathForLocalIndexPath:newIndexPath];

    [(UITableView *)_wrappedView moveRowAtIndexPath:globalIndexPath toIndexPath:globalNewIndexPath];
}

- (NSIndexPath *)indexPathForSelectedRow
{
    NSIndexPath *globalIndexPath = [(UITableView *)_wrappedView indexPathForSelectedRow];
    return [_mapping localIndexPathForGlobalIndexPath:globalIndexPath];
}

- (NSArray *)indexPathsForSelectedRows
{
    NSArray *globalIndexPaths = [(UITableView *)_wrappedView indexPathsForSelectedRows];
    if (!globalIndexPaths)
        return nil;
    return [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths];
}

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition
{
    NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:indexPath];
    [(UITableView *)_wrappedView selectRowAtIndexPath:globalIndexPath animated:animated scrollPosition:scrollPosition];
}

- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:indexPath];
    [(UITableView *)_wrappedView deselectRowAtIndexPath:globalIndexPath animated:animated];
}

- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:indexPath];
    return [(UITableView *)_wrappedView dequeueReusableCellWithIdentifier:identifier forIndexPath:globalIndexPath];
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

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath*)indexPath
{
    return [(UICollectionView *)_wrappedView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

- (id)dequeueReusableSupplementaryViewOfKind:(NSString*)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath*)indexPath
{
    return [(UICollectionView *)_wrappedView dequeueReusableSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier forIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

// returns nil or an array of selected index paths
- (NSArray *)indexPathsForSelectedItems
{
    NSArray *globalIndexPaths = [(UICollectionView *)_wrappedView indexPathsForSelectedItems];
    if (!globalIndexPaths)
        return nil;
    return [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths];
}

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition
{
    [(UICollectionView *)_wrappedView selectItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath] animated:animated scrollPosition:scrollPosition];
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    [(UICollectionView *)_wrappedView deselectItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath] animated:animated];
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
    NSUInteger globalSection = [_mapping globalSectionForLocalSection:section];
    return [(UICollectionView *)_wrappedView numberOfItemsInSection:globalSection];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [(UICollectionView *)_wrappedView layoutAttributesForItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    return [(UICollectionView *)_wrappedView layoutAttributesForSupplementaryElementOfKind:kind atIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point
{
    NSIndexPath *globalIndexPath = [(UICollectionView *)_wrappedView indexPathForItemAtPoint:point];
    return [_mapping localIndexPathForGlobalIndexPath:globalIndexPath];
}

- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [(UICollectionView *)_wrappedView cellForItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath]];
}

- (NSArray *)indexPathsForVisibleItems
{
    NSArray *globalIndexPaths = [(UICollectionView *)_wrappedView indexPathsForVisibleItems];
    if (![globalIndexPaths count])
        return nil;

    return [_mapping localIndexPathsForGlobalIndexPaths:globalIndexPaths];
}

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    [(UICollectionView *)_wrappedView scrollToItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath] atScrollPosition:scrollPosition animated:animated];
}

- (void)insertSections:(NSIndexSet *)sections
{
    NSMutableIndexSet *globalSections = [[NSMutableIndexSet alloc] init];

    [sections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        NSUInteger globalSection = [_mapping globalSectionForLocalSection:localSection];
        [globalSections addIndex:globalSection];
    }];

    [(UICollectionView *)_wrappedView insertSections:sections];
}

- (void)deleteSections:(NSIndexSet *)sections
{
    NSMutableIndexSet *globalSections = [[NSMutableIndexSet alloc] init];

    [sections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        NSUInteger globalSection = [_mapping globalSectionForLocalSection:localSection];
        [globalSections addIndex:globalSection];
    }];

    [(UICollectionView *)_wrappedView deleteSections:sections];
}

- (void)reloadSections:(NSIndexSet *)sections
{
    NSMutableIndexSet *globalSections = [[NSMutableIndexSet alloc] init];

    [sections enumerateIndexesUsingBlock:^(NSUInteger localSection, BOOL *stop) {
        NSUInteger globalSection = [_mapping globalSectionForLocalSection:localSection];
        [globalSections addIndex:globalSection];
    }];

    [(UICollectionView *)_wrappedView reloadSections:sections];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSMutableArray *globalIndexPaths = [NSMutableArray arrayWithCapacity:[indexPaths count]];
    for (NSIndexPath *localIndexPath in indexPaths) {
        NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:localIndexPath];
        [globalIndexPaths addObject:globalIndexPath];
    }

    [(UICollectionView *)_wrappedView insertItemsAtIndexPaths:globalIndexPaths];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSMutableArray *globalIndexPaths = [NSMutableArray arrayWithCapacity:[indexPaths count]];
    for (NSIndexPath *localIndexPath in indexPaths) {
        NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:localIndexPath];
        [globalIndexPaths addObject:globalIndexPath];
    }

    [(UICollectionView *)_wrappedView deleteItemsAtIndexPaths:globalIndexPaths];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSMutableArray *globalIndexPaths = [NSMutableArray arrayWithCapacity:[indexPaths count]];
    for (NSIndexPath *localIndexPath in indexPaths) {
        NSIndexPath *globalIndexPath = [_mapping globalIndexPathForLocalIndexPath:localIndexPath];
        [globalIndexPaths addObject:globalIndexPath];
    }

    [(UICollectionView *)_wrappedView reloadItemsAtIndexPaths:globalIndexPaths];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    [(UICollectionView *)_wrappedView moveItemAtIndexPath:[_mapping globalIndexPathForLocalIndexPath:indexPath] toIndexPath:[_mapping globalIndexPathForLocalIndexPath:newIndexPath]];
}

@end
