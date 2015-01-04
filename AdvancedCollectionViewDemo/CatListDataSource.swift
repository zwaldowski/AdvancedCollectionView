//
//  CatListDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/3/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

class CatListDataSource: BasicDataSource {
    
    /// Is this list showing the cats in reverse order?
    var reversed: Bool = false {
        didSet {
            resetContent()
            setNeedsLoadContent()
        }
    }
    
    // MARK: Boilerplate
    
    typealias Item = AAPLCat
    typealias Items = [Item]
    
    private var _items = Items()
    private var items: Items {
        get { return _items }
        set { setItems(newValue, animated: false) }
    }
    
    private func setItems(items: Items, animated: Bool) {
        let oldItems = _items
        _items = items
        notifyUpdate(oldItems: oldItems, newItems: items, animated: animated)
    }
    
    func indexPaths(forItem item: Item) -> [NSIndexPath] {
        return indexPaths(forItem: item, items: _items)
    }
    
    subscript(indexPath: NSIndexPath) -> Item? {
        return item(atIndexPath: indexPath, items: _items)
    }
    
    // MARK: DataSource
    
    
    
    override func resetContent() {
        super.resetContent()
        items = []
    }
    
    override func registerReusableViews(#collectionView: UICollectionView) {
        super.registerReusableViews(collectionView: collectionView)
        register(typeForCell: BasicCell.self, collectionView: collectionView)
    }
    
    override func loadContent() {
        startLoadingContent { (loading) -> () in
            AAPLDataAccessManager.shared().fetchCatListReversed(self.reversed) {
                [weak self]
                (array, error) in
                
                if self == nil { return }
                
                if !loading.isCurrent {
                    loading.ignore()
                    return
                }
                
                if error != nil {
                    loading.error(error)
                    return
                }
                
                let list = array as Items
                if list.isEmpty {
                    loading.noContent { self!.items = list }
                } else {
                    loading.update { self!.items = list }
                }
            }
            
        }
    }
    
    // MARK: UICollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cat = self[indexPath]!
        let cell = dequeue(cellOfType: BasicCell.self, collectionView: collectionView, indexPath: indexPath)
        cell.style = .Subtitle
        cell.primaryLabel.text = cat.name
        cell.primaryLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        cell.secondaryLabel.text = cat.shortDescription
        cell.secondaryLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption2)
        return cell
    }
    
}
