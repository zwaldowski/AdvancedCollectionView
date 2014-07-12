/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLBasicDataSource.h"

@implementation AAPLBasicDataSource

- (void)resetContent
{
    [super resetContent];
    self.items = @[];
}

- (id)itemAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.length < 2) return nil;
	NSUInteger itemIndex = [indexPath indexAtPosition:1];
	if (itemIndex >= _items.count) return nil;
	return _items[itemIndex];
}

- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexSet *removedIndexes = [NSIndexSet indexSetWithIndex:(NSUInteger)indexPath.item];
    [self removeItemsAtIndexes:removedIndexes];
}

- (void)setItems:(NSArray *)items
{
    [self setItems:items animated:NO];
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated
{
    if (_items == items || [_items isEqualToArray:items])
        return;

    if (!animated) {
        _items = [items copy];
        [self updateLoadingStateFromItems];
        [self notifySectionsRefreshed:[NSIndexSet indexSetWithIndex:0]];
        return;
    }

    NSOrderedSet *oldItemSet = [NSOrderedSet orderedSetWithArray:_items];
    NSOrderedSet *newItemSet = [NSOrderedSet orderedSetWithArray:items];

    NSMutableOrderedSet *deletedItems = [oldItemSet mutableCopy];
    [deletedItems minusOrderedSet:newItemSet];

    NSMutableOrderedSet *newItems = [newItemSet mutableCopy];
    [newItems minusOrderedSet:oldItemSet];

    NSMutableOrderedSet *movedItems = [newItemSet mutableCopy];
    [movedItems intersectOrderedSet:oldItemSet];

    NSMutableArray *deletedIndexPaths = [NSMutableArray arrayWithCapacity:[deletedItems count]];
    for (id deletedItem in deletedItems) {
        [deletedIndexPaths addObject:[NSIndexPath indexPathForItem:[oldItemSet indexOfObject:deletedItem] inSection:0]];
    }

    NSMutableArray *insertedIndexPaths = [NSMutableArray arrayWithCapacity:[newItems count]];
    for (id newItem in newItems) {
        [insertedIndexPaths addObject:[NSIndexPath indexPathForItem:[newItemSet indexOfObject:newItem] inSection:0]];
    }

    NSMutableArray *fromMovedIndexPaths = [NSMutableArray arrayWithCapacity:[movedItems count]];
    NSMutableArray *toMovedIndexPaths = [NSMutableArray arrayWithCapacity:[movedItems count]];
    for (id movedItem in movedItems) {
        [fromMovedIndexPaths addObject:[NSIndexPath indexPathForItem:[oldItemSet indexOfObject:movedItem] inSection:0]];
        [toMovedIndexPaths addObject:[NSIndexPath indexPathForItem:[newItemSet indexOfObject:movedItem] inSection:0]];
    }

    _items = [items copy];
    [self updateLoadingStateFromItems];

    if ([deletedIndexPaths count])
        [self notifyItemsRemovedAtIndexPaths:deletedIndexPaths];

    if ([insertedIndexPaths count])
        [self notifyItemsInsertedAtIndexPaths:insertedIndexPaths];

	[fromMovedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath *fromIndexPath, NSUInteger idx, BOOL *stop) {
		NSIndexPath *toIndexPath = toMovedIndexPaths[idx];
		[self notifyItemMovedFromIndexPath:fromIndexPath toIndexPaths:toIndexPath];
	}];
}

- (void)updateLoadingStateFromItems
{
    NSString *loadingState = self.loadingState;
    NSUInteger numberOfItems = [_items count];
    if (numberOfItems && [loadingState isEqualToString:AAPLLoadStateNoContent])
        self.loadingState = AAPLLoadStateContentLoaded;
    else if (!numberOfItems && [loadingState isEqualToString:AAPLLoadStateContentLoaded])
        self.loadingState = AAPLLoadStateNoContent;
}

#pragma mark - KVC methods for item property

- (NSUInteger)countOfItems __unused
{
    return [_items count];
}

- (NSArray *)itemsAtIndexes:(NSIndexSet *)indexes __unused
{
    return [_items objectsAtIndexes:indexes];
}

- (void)getItems:(__unsafe_unretained id *)buffer range:(NSRange)range __unused
{
    return [_items getObjects:buffer range:range];
}

- (void)insertItems:(NSArray *)array atIndexes:(NSIndexSet *)indexes __unused
{
    NSMutableArray *newItems = [_items mutableCopy];
    [newItems insertObjects:array atIndexes:indexes];

    _items = newItems;

    NSMutableArray *insertedIndexPaths = [NSMutableArray arrayWithCapacity:[indexes count]];
    [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [insertedIndexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
    }];

    [self updateLoadingStateFromItems];
    [self notifyItemsInsertedAtIndexPaths:insertedIndexPaths];
}

- (void)removeItemsAtIndexes:(NSIndexSet *)indexes __unused
{
    NSUInteger newCount = [_items count] - [indexes count];
    NSMutableArray *newItems = newCount > 0 ? [[NSMutableArray alloc] initWithCapacity:newCount] : nil;

    // set up a delayed set of batch update calls for later execution
    __block dispatch_block_t batchUpdates = ^{};
    batchUpdates = [batchUpdates copy];

    [_items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_block_t oldUpdates = batchUpdates;
        if ([indexes containsIndex:idx]) {
            // we're removing this item
            batchUpdates = ^{
                oldUpdates();
                [self notifyItemsRemovedAtIndexPaths:@[[NSIndexPath indexPathForItem:idx inSection:0]]];
            };
        }
        else {
            // we're keeping this item
            NSUInteger newIdx = [newItems count];
            [newItems addObject:obj];
            batchUpdates = ^{
                oldUpdates();
                [self notifyItemMovedFromIndexPath:[NSIndexPath indexPathForItem:idx inSection:0] toIndexPaths:[NSIndexPath indexPathForItem:newIdx inSection:0]];
            };
        }
        batchUpdates = [batchUpdates copy];
    }];

    _items = newItems;

    [self notifyBatchUpdate:^{
        batchUpdates();
        [self updateLoadingStateFromItems];
    } complete:NULL];
}

- (void)replaceItemsAtIndexes:(NSIndexSet *)indexes withItems:(NSArray *)array __unused
{
    NSMutableArray *newItems = [_items mutableCopy];
    [newItems replaceObjectsAtIndexes:indexes withObjects:array];

    _items = newItems;

    NSMutableArray *replacedIndexPaths = [NSMutableArray arrayWithCapacity:[indexes count]];
    [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [replacedIndexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
    }];

    [self notifyItemsRefreshedAtIndexPaths:replacedIndexPaths];
}

#pragma mark - UICollectionViewDataSource methods

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.obscuredByPlaceholder)
        return 0;

    return [_items count];
}

@end
