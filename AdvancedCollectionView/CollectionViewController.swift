//
//  CollectionViewController.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/28/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

private var dataSourceContext = 0

public class CollectionViewController: UICollectionViewController, DataSourceContainer {
    
    private let updateDebugging = true
    private var firstDisplay = false
    
    private var presenterLayout: DataSourcePresenter? {
        return collectionViewLayout as? DataSourcePresenter
    }

    deinit {
        collectionView?.removeObserver(self, forKeyPath: "dataSource", context: &dataSourceContext)
    }
    
    public override func loadView() {
        super.loadView()
        
        //  We need to know when the data source changes on the collection view so we can become the delegate for any data source subclasses.
        collectionView?.addObserver(self, forKeyPath: "dataSource", options: nil, context: &dataSourceContext)
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        prepareForDisplay(inCollectionView: collectionView!)
    }

    private func prepareForDisplay(inCollectionView collectionView: UICollectionView, onlyAfterFirst: Bool = false) {
        if firstDisplay && onlyAfterFirst { return }

        firstDisplay = true

        if let ds = collectionView.dataSource as? DataSource {
            if ds.container == nil {
                ds.container = self
            }

            ds.registerReusableViews(collectionView: collectionView)
            ds.setNeedsLoadContent()
        }
    }
    
    public override var collectionView: UICollectionView? {
        didSet {
            oldValue?.removeObserver(self, forKeyPath: "dataSource", context: &dataSourceContext)
            collectionView?.addObserver(self, forKeyPath: "dataSource", options: nil, context: &dataSourceContext)
        }
    }
    
    public override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if context == &dataSourceContext {
            prepareForDisplay(inCollectionView: object as! UICollectionView, onlyAfterFirst: true)
        } else {
            // For change contexts that aren't the data source, pass them to super.
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    // MARK: DataSourceContainer
    
    public let isObscuredByPlaceholder: Bool = false
    
    public func localSection(global section: Int) -> Int {
        return section
    }
    
    public func globalSection(local section: Int) -> Int {
        return section
    }
    
    public func containedDataSource(forSection section: Int) -> DataSource {
        // TODO: downcast now
        return collectionView?.dataSource as! DataSource
    }
    
    public func dataSourceWillPerform(dataSource: DataSource, sectionAction: SectionAction) {
        if updateDebugging {
            debugPrintln(sectionAction)
        }
        
        presenterLayout?.dataSourceWillPerform(dataSource, sectionAction: sectionAction)
        
        switch (sectionAction, collectionView) {
        case (.Insert(let indexSet, _), .Some(let collectionView)):
            collectionView.insertSections(indexSet)
        case (.Remove(let indexSet, _), .Some(let collectionView)):
            collectionView.deleteSections(indexSet)
        case (.Reload(let indexSet), .Some(let collectionView)):
            collectionView.reloadSections(indexSet)
        case (.Move(let from, let to, _), .Some(let collectionView)):
            collectionView.moveSection(from, toSection: to)
        case (.ReloadGlobal, .Some(let collectionView)) where presenterLayout == nil:
            collectionView.reloadData()
        default: break
        }
    }
    
    public func dataSourceWillPerform(dataSource: DataSource, itemAction: ItemAction) {
        if updateDebugging {
            debugPrintln(itemAction)
        }
        
        switch (itemAction, collectionView) {
        case (.Insert(let indexPaths), .Some(let collectionView)):
            collectionView.insertItemsAtIndexPaths(indexPaths)
        case (.Remove(let indexPaths), .Some(let collectionView)):
            collectionView.deleteItemsAtIndexPaths(indexPaths)
        case (.Reload(let indexPaths), .Some(let collectionView)):
            collectionView.reloadItemsAtIndexPaths(indexPaths)
        case (.Move(let from, let to), .Some(let collectionView)):
            collectionView.moveItemAtIndexPath(from, toIndexPath: to)
        case (.ReloadAll, .Some(let collectionView)):
            collectionView.reloadData()
        case (.BatchUpdate(let update, let completion), .Some(let collectionView)):
            collectionView.performBatchUpdates(update, completion: completion)
        default: break
        }
    }
    
}
