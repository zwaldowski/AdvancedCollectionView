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
    
    private let cat: AAPLCat
    init(cat: AAPLCat) {
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
    
    typealias Item = AAPLCatSighting
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
        register(typeForCell: CatSightingCell.self, collectionView: collectionView)
    }
    
    override func loadContent() {
        startLoadingContent { (loading) -> () in
            AAPLDataAccessManager.shared().fetchSightingsForCat(self.cat) {
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
                loading.update { self!.items = list }
            }
            
        }
    }
    
    // MARK: UICollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let sighting = self[indexPath]!
        let cell = dequeue(cellOfType: CatSightingCell.self, collectionView: collectionView, indexPath: indexPath)
        cell.configure(sighting, dateFormatter: dateFormatter)
        return cell
    }
    
}
