//
//  BasicDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/23/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

public func diff<New: CollectionType, Old: SequenceType where New.Generator.Element: Hashable, Old.Generator.Element == New.Generator.Element>(#oldItems: Old, #newItems: New) -> (deleted: [Int], inserted: [Int], moved: [(Int, Int)]) {
    let oldItemSet = OrderedSet(oldItems)
    let newItemSet = OrderedSet(newItems)
    
    let deletedIndexes = filter(enumerate(oldItemSet)) { (_, element) in
        !newItemSet.contains(element)
    }.map { (index, _) -> Int in
        return index
    }
    
    let insertedIndexes = filter(enumerate(newItemSet)) { (_, element) in
        !oldItemSet.contains(element)
    }.map { (index, _) -> Int in
        return index
    }
    
    let movedIndexes = filter(enumerate(oldItemSet)) { (_, element) in
        newItemSet.contains(element)
    }.map { (index, element) -> (Int, Int) in
        let indexInNew = find(newItemSet, element)!
        return (index, indexInNew)
    }
    
    return (deletedIndexes, insertedIndexes, movedIndexes)
}

public func simpleDiff<New: CollectionType, Old: CollectionType where Old.Generator.Element == New.Generator.Element>(#oldItems: Old, #newItems: New) -> (reloaded: Range<Int>, deleted: Range<Int>, inserted: Range<Int>) {
    func emptyRange(start: Int) -> Range<Int> {
        return start..<start
    }
    
    let oldCount = underestimateCount(oldItems)
    let newCount = underestimateCount(newItems)
    
    if oldCount > newCount {
        return (0..<newCount, newCount..<oldCount, emptyRange(newCount))
    } else if oldCount < newCount {
        return (0..<oldCount, emptyRange(oldCount), oldCount..<newCount)
    } else {
        let empty = emptyRange(oldCount)
        return (0..<newCount, empty, empty)
    }
}

/// A data source that manages a single section of items backed by an array.
public class BasicDataSource: DataSource {
    
    public func notifyUpdate<New: CollectionType, Old: CollectionType where New.Generator.Element: Hashable, Old.Generator.Element == New.Generator.Element>(#oldItems: Old, newItems: New, animated: Bool) {
        let oldEmpty = isEmpty(oldItems)
        let newEmpty = isEmpty(newItems)
        
        if !animated || oldEmpty && !newEmpty {
            updateLoadingState(newEmpty)
            notifySectionsReloaded(NSIndexSet(index: 0))
            return
        }
        
        let (deleted, inserted, moved) = diff(oldItems: oldItems, newItems: newItems)
        
        updateLoadingState(newEmpty)
        notifyItemsRemoved(deleted, inSection: 0)
        notifyItemsInserted(inserted, inSection: 0)
        notifyItemsMoved(moved, inSection: 0)
    }
    
    public func notifyUpdateSimple<New: CollectionType, Old: CollectionType where Old.Generator.Element == New.Generator.Element>(#oldItems: Old, newItems: New) {
        let oldEmpty = isEmpty(oldItems)
        let newEmpty = isEmpty(newItems)

        let (reloaded, deleted, inserted) = simpleDiff(oldItems: oldItems, newItems: newItems)
        
        updateLoadingState(newEmpty)
        if oldEmpty && !newEmpty || !oldEmpty && newEmpty {
            notifySectionsReloaded(NSIndexSet(index: 0))
        }
        notifyItemsReloaded(reloaded, inSection: 0)
        notifyItemsRemoved(deleted, inSection: 0)
        notifyItemsInserted(inserted, inSection: 0)
    }
    
    public func updateLoadingState(isEmpty: Bool) {
        switch (loadingState, isEmpty) {
        case (.NoContent, false):
            loadingState = .Loaded
        case (.Loaded, true):
            loadingState = .NoContent
        default:
            break
        }
    }
    
    public func indexPaths<T: Equatable, S: SequenceType where S.Generator.Element == T>(forItem item: T, items: S) -> [NSIndexPath] {
        return lazy(enumerate(items)).filter { (_, element) in
            return element == item
        }.map { (index, _) in
            NSIndexPath(0, index)
        }.array
    }
    
    public func item<T, C: CollectionType where C.Generator.Element == T, C.Index == Int>(atIndexPath indexPath: NSIndexPath, items: C) -> T? {
        let index = indexPath.item
        if index < items.endIndex {
            return items[index]
        }
        return nil
    }
    
}
