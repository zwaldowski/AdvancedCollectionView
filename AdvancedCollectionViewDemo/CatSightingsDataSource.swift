//
//  CatSightingsDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/4/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

class CatSightingsDataSource: BasicDataSource {
    
    private let cat: Cat
    init(cat: Cat) {
        self.cat = cat
        super.init()
    }
    
    private lazy var dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .ShortStyle;
        return formatter
    }()
    
    // MARK: Boilerplate
    
    typealias Item = CatSighting
    typealias Items = [Item]
    
    private var items: Items = Items() {
        didSet {
            notifyUpdate(oldItems: oldValue, newItems: items, animated: false)
        }
    }
    
    func indexPaths(forItem item: Item) -> [NSIndexPath] {
        return indexPaths(forItem: item, items: items)
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
        
        collectionView.register(typeForCell: CatSightingCell.self)
    }
    
    override func loadContent() {
        startLoadingContent { (loading) -> () in
            DataAccessManager.shared.fetchSightings(cat: self.cat) {
                [weak self] (array) in
                
                switch (self, loading.isCurrent, array) {
                case (.None, _, _): return
                case (_, false, _): return loading.ignore()
                case (_, _, .None): return loading.error()
                case (.Some(let me), true, .Some(let list)):
                    loading.update { me.items = list }
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
        let sighting = self[indexPath]!
        let cell = collectionView.dequeue(cellOfType: CatSightingCell.self, indexPath: indexPath)
        cell.configure(sighting, dateFormatter: dateFormatter)
        return cell
    }
    
}
