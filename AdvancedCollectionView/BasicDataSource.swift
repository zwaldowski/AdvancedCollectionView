//
//  BasicDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/23/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

/// A data source that manages a single section of items backed by an array.
public class BasicDataSource<T: Hashable>: DataSource {
    
    private var _items = [T]()

    public var items: [T] {
        get { return _items }
        set { setItems(newValue, animated: false) }
    }
    
    public func setItems(items: [T], animated: Bool) {
        if !animated {
            _items = items
            updateLoadingStateFromItems()
            notifySectionsReloaded(NSIndexSet(index: 0))
            return
        }
        
        let oldItemSet = OrderedSet(_items)
        let newItemSet = OrderedSet(items)
        
        let deletedIndexPaths = filter(enumerate(oldItemSet)) { (index, element) in
            !newItemSet.contains(element)
        }.map { (index, element) -> NSIndexPath in
            NSIndexPath(forItem: index, inSection: 0)
        }
        
        let insertedIndexPaths = filter(enumerate(newItemSet)) { (index, element) in
            !oldItemSet.contains(element)
        }.map { (index, element) -> NSIndexPath in
            NSIndexPath(forItem: index, inSection: 0)
        }
        
        let movedIndexPaths = filter(enumerate(oldItemSet)) { (index, element) in
            newItemSet.contains(element)
        }.map { (index, element) -> (NSIndexPath, NSIndexPath) in
            let indexInNew = find(newItemSet, element)!
            return (NSIndexPath(forItem: index, inSection: 0), NSIndexPath(forItem: indexInNew, inSection: 0))
        }
        
        _items = items
        updateLoadingStateFromItems()
        
        if !deletedIndexPaths.isEmpty {
            notifyItemsRemoved(deletedIndexPaths)
        }
        
        if !insertedIndexPaths.isEmpty {
            notifyItemsInserted(insertedIndexPaths)
        }
        
        for (oldIndexPath, newIndexPath) in movedIndexPaths {
            notifyItemMoved(from: oldIndexPath, to: newIndexPath)
        }
    }
    
    public func indexPaths(forItem item: T) -> [NSIndexPath] {
        return lazy(enumerate(_items)).filter({
            $0.1 == item
        }).map({
            NSIndexPath(forItem: $0.0, inSection: 0)
        }).array
    }
    
    public subscript(indexPath: NSIndexPath) -> T? {
        let index = indexPath.item
        if index < items.endIndex {
            return items[index]
        }
        return nil
    }
    
    // MARK: DataSource
    
    public override func resetContent() {
        super.resetContent()
        items = []
    }
    
    public func updateLoadingStateFromItems() {
        switch (loadingState, _items.count) {
        case (.NoContent, let x) where x > 0:
            loadingState = .Loaded
        case (.Loaded, 0):
            loadingState = .NoContent
        default:
            break
        }
    }
    
}
