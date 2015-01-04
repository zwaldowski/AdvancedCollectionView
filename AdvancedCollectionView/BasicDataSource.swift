//
//  BasicDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/23/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

func updateDiff<New: CollectionType, Old: SequenceType where New.Generator.Element: Hashable, Old.Generator.Element == New.Generator.Element>(#oldItems: Old, newItems: New) -> (deleted: [Int], inserted: [Int], moved: [(Int, Int)]) {
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

/// A data source that manages a single section of items backed by an array.
public class BasicDataSource: DataSource {
    
    public func notifyUpdate<New: CollectionType, Old: SequenceType where New.Generator.Element: Hashable, Old.Generator.Element == New.Generator.Element>(#oldItems: Old, newItems: New, animated: Bool) {
        if !animated {
            updateLoadingState(isEmpty(newItems))
            notifySectionsReloaded(NSIndexSet(index: 0))
            return
        }
        
        let (deleted, inserted, moved) = updateDiff(oldItems: oldItems, newItems)
        
        updateLoadingState(isEmpty(newItems))
        
        notifyItemsRemoved(deleted.map {
            NSIndexPath(0, $0)
        })
        
        notifyItemsInserted(inserted.map {
            NSIndexPath(0, $0)
        })
        
        for (oldIndex, newIndex) in moved {
            notifyItemMoved(from: NSIndexPath(0, oldIndex), to: NSIndexPath(0, newIndex))
        }
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
