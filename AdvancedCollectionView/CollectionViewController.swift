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
        return collectionView?.collectionViewLayout as? DataSourcePresenter
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
        get { return super.collectionView }
        set {
            let oldCollectionView = collectionView
            
            // Always call super, because we don't know EXACTLY what UICollectionViewController does in -setCollectionView:.
            super.collectionView = newValue
            
            oldCollectionView?.removeObserver(self, forKeyPath: "dataSource", context: &dataSourceContext)
            newValue?.addObserver(self, forKeyPath: "dataSource", options: nil, context: &dataSourceContext)
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
        
        let layout = presenterLayout

        layout?.dataSourceWillPerform(dataSource, sectionAction: sectionAction)

        switch (sectionAction, layout) {
        case (.Insert(let indexSet, _), _):
            collectionView?.insertSections(indexSet)
        case (.Remove(let indexSet, _), _):
            collectionView?.deleteSections(indexSet)
        case (.Reload(let indexSet), _):
            collectionView?.reloadSections(indexSet)
        case (.Move(let from, let to, _), _):
            collectionView?.moveSection(from, toSection: to)
        case (.ReloadGlobal, .None):
            collectionView?.reloadData()
        default: break
        }
    }
    
    public func dataSourceWillPerform(dataSource: DataSource, itemAction: ItemAction) {
        if updateDebugging {
            debugPrintln(itemAction)
        }
        
        switch itemAction {
        case .Insert(let indexPaths):
            collectionView?.insertItemsAtIndexPaths(indexPaths)
        case .Remove(let indexPaths):
            collectionView?.deleteItemsAtIndexPaths(indexPaths)
        case .Reload(let indexPaths):
            collectionView?.reloadItemsAtIndexPaths(indexPaths)
        case .Move(let from, let to):
            collectionView?.moveItemAtIndexPath(from, toIndexPath: to)
        case .ReloadAll:
            collectionView?.reloadData()
        case .BatchUpdate(let update, let completion):
            collectionView?.performBatchUpdates(update, completion: completion)
        case .WillLoad, .DidLoad:
            break
        }
    }
    
}
