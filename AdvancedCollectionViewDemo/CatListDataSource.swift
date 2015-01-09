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
    
    typealias Item = Cat
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
        
        collectionView.register(typeForCell: BasicCell.self)
    }
    
    override func loadContent() {
        startLoadingContent { (loading) -> () in
            DataAccessManager.shared.fetchCatList(reversed: self.reversed) {
                [weak self] (array) in
                
                switch (self, loading.isCurrent, array) {
                case (.None, _, _): return
                case (_, false, _): return loading.ignore()
                case (_, _, .None): return loading.error()
                case (.Some(let me), true, .Some(let arr)):
                    if arr.isEmpty {
                        loading.noContent { me.items = arr }
                    } else {
                        loading.update { me.items = arr }
                    }
                default: break
                }
            }
        }
    }
    
    // MARK: UICollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cat = self[indexPath]
        let cell = collectionView.dequeue(cellOfType: BasicCell.self, indexPath: indexPath)
        
        cell.style = .Subtitle
        cell.primaryLabel.text = cat?.name
        cell.primaryLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        cell.secondaryLabel.text = cat?.shortDescription
        cell.secondaryLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption2)
        return cell
    }
    
}
