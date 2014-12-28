//
//  DataSource+CollectionView.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/17/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import Foundation

// MARK: SequenceType

extension DataSource: SequenceType {
    
    public func generate() -> GeneratorOf<Section> {
        return Section.all(numberOfSections: numberOfSections)
    }
    
}

// MARK: UICollectionViewDataSource

extension DataSource: UICollectionViewDataSource {
    
    public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return numberOfSections
    }
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        fatalError("This method must be overridden in a subclass")
    }
    
    public final func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        if kind == ElementKindPlaceholder {
            return dequeuePlaceholderView(collectionView: collectionView, indexPath: indexPath)
        }

        
        // Need to map the global index path to an index path relative to the target data source, because we're handling this method at the root of the data source tree. If I allowed subclasses to handle this, this wouldn't be necessary. But because of the way headers layer, it's more efficient to snapshot the section and find the metrics once.
        var section: Section
        var dataSource: DataSource
        var localIndexPath: NSIndexPath
        var localItem: Int
        
        if indexPath.length == 1 {
            section = .Global
            dataSource = self
            localIndexPath = indexPath
            localItem = indexPath[0]
        } else {
            (dataSource, localIndexPath) = childDataSource(forGlobalIndexPath: indexPath)
            section = .Index(indexPath.section)
            let info = childDataSource(forGlobalIndexPath: indexPath)
            localIndexPath = info.1
            section = Section.Index(localIndexPath[0])
            localItem = localIndexPath[1]
        }
        
        let sectionMetrics = snapshotMetrics(section: section)
        let supplements = lazy(sectionMetrics.supplementaryViews).filter {
            $0.kind == kind
        }
        
        var metrics: SupplementaryMetrics! = nil
        for (i, supplMetrics) in enumerate(supplements) {
            if i == localItem {
                metrics = supplMetrics
                break
            }
        }
        
        let view = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: metrics.reuseIdentifier, forIndexPath: indexPath) as UICollectionReusableView
        
        if let configure = metrics.configureView {
            configure(view: view, dataSource: dataSource, indexPath: localIndexPath)
        }
        
        return view
    }
    
}

// MARK: CollectionViewDataSourceGridLayout

extension DataSource: CollectionViewDataSourceGridLayout {
    
    public func sizeFittingSize(size: CGSize, itemAtIndexPath indexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize {
        let cell = self.collectionView(collectionView, cellForItemAtIndexPath: indexPath)
        let fittingSize = cell.aapl_preferredLayoutSizeFittingSize(size)
        cell.removeFromSuperview() // force it to get put in the reuse pool now
        return fittingSize
    }
    
    public func sizeFittingSize(size: CGSize, supplementaryElementOfKind kind: String, indexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize {
        let cell = self.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, atIndexPath: indexPath)
        let fittingSize = cell.aapl_preferredLayoutSizeFittingSize(size)
        cell.removeFromSuperview() // force it to get put in the reuse pool now
        return fittingSize
    }
    
    public func snapshotMetrics() -> [Section : SectionMetrics] {
        let defaultBackground = UIColor.whiteColor()
        return reduce(self, [:]) { (var dict, section) in
            var metrics = self.snapshotMetrics(section: section)
            if metrics.backgroundColor == nil {
                metrics.backgroundColor = defaultBackground
            }
            dict[section] = metrics
            return dict
        }
    }
        
}
