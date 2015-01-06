//
//  TextValueDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/4/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

/// A data source that populates its cells based on key/value information from a source object. Any items for which the object does not have a value will not be displayed. This is a tad more complex than key-value data source, because each item will be used to create a single item section. The value of the label will be used to create a section header.
class TextValueDataSource<T>: BasicDataSource {
    
    typealias Item = KeyValue<T>
    typealias Items = [Item]
    
    private let _source: [T]
    private var source: T {
        return _source[0]
    }
    
    init(source: T) {
        _source = [ source ]
        super.init()
        
        defaultMetrics.selectedBackgroundColor = UIColor.clearColor()
        
        // Create a section header that will pull the text of the header from the label of the item.
        var header = SupplementaryMetrics(kind: UICollectionElementKindSectionHeader)
        header.viewType = SectionHeaderView.self
        header.configure { (view: SectionHeaderView, dataSource: TextValueDataSource<T>, indexPath) in
            let value = dataSource.items[indexPath[0]]
            view.leadingLabel.text = value.label
        }
        addHeader(header, forKey: "largeHeader")
    }
    
    var items: Items = Items() {
        didSet {
            let newEmpty = isEmpty(items)
            let (reloaded, deleted, inserted) = diff(oldItems: oldValue, newItems: items)
            
            updateLoadingState(newEmpty)
            notifySectionsReloaded(reloaded)
            notifySectionsInserted(inserted)
            notifySectionsRemoved(deleted)
        }
    }
    
    // MARK: DataSource
    
    override var numberOfSections: Int {
        return items.count
    }
    
    override func registerReusableViews(#collectionView: UICollectionView) {
        super.registerReusableViews(collectionView: collectionView)
        register(typeForCell: TextValueCell.self, collectionView: collectionView)
    }
    
    // MARK: UICollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isObscuredByPlaceholder { return 0 }
        
        let value = items[section]
        let text = value.getValue(source)
        
        return text.isEmpty ? 0 : 1
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = dequeue(cellOfType: TextValueCell.self, collectionView: collectionView, indexPath: indexPath)
        let value = items[indexPath[0]]
        cell.configure(value.getValue(source))
        return cell
    }
    
}
