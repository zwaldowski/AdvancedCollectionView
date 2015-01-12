//
//  KeyValueDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/4/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

struct KeyValue<T> {
    let label: String
    let getValue: T -> String?
}

/// A data source that populates its cells based on key/value information from a source object. Any items for which the object does not have a value will not be displayed.
final class KeyValueDataSource<T>: BasicDataSource {
    
    typealias Item = KeyValue<T>
    typealias Items = [Item]
    
    private var _source: [T]
    var source: T {
        get {
            return _source[0]
        }
        set {
            _source[0] = newValue
        }
    }
    
    init(source: T) {
        _source = [ source ]
        super.init()
    }
    
    // MARK: Boilerplate
    
    private var _items: Items = Items() {
        didSet {
            let newEmpty = isEmpty(_items)
            
            updateLoadingState(newEmpty)
            notifyUpdateSimple(oldItems: oldValue, newItems: _items)
        }
    }

    var items: Items {
        get { return _items }
        set {
            // Filter out any items that don't have a value, because it looks sloppy when rows have a label but no value
            _items = newValue.filter {
                let empty = $0.getValue(self.source)?.isEmpty ?? true
                return !empty
            }
        }
    }
    
    subscript(indexPath: NSIndexPath) -> Item? {
        return item(atIndexPath: indexPath, items: items)
    }
    
    // MARK: DataSource

    override func resetContent() {
        super.resetContent()
        items = []
    }
    
    override func registerReusableViews(#collectionView: UICollectionView) {
        super.registerReusableViews(collectionView: collectionView)
        
        collectionView.register(typeForCell: BasicCell.self)
    }
    
    // MARK: UICollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeue(cellOfType: BasicCell.self, indexPath: indexPath)
        let value = self[indexPath]
        cell.primaryLabel.text = value?.label
        cell.secondaryLabel.text = value?.getValue(source)
        return cell
    }

}
