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
    
    private func info(#indexPath: NSIndexPath) -> (section: Section, index: Int, dataSource: DataSource) {
        if indexPath.length == 1 {
            return (.Global, indexPath[0], self)
        } else {
            let section = Section.Index(indexPath[0])
            return (section, indexPath[1], childDataSource(forSection: section))
        }
    }
    
    public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return numberOfSections
    }
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        fatalError("This method must be overridden in a subclass")
    }
    
    public func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        if kind == ElementKindPlaceholder {
            return dequeuePlaceholderView(collectionView: collectionView, indexPath: indexPath)
        }
        
        let (section, item) = indexPath.globalInfo
        
        var dataSource: DataSource
        switch (section) {
        case .Index:
            dataSource = childDataSource(forSection: section)
        default:
            dataSource = self
        }
        
        let supplements = lazy(snapshotMetrics(section: section).supplementaryViews).filter {
            $0.kind == kind
        }
        
        var metrics: SupplementaryMetrics! = nil
        for (i, supplMetrics) in enumerate(supplements) {
            if i == item {
                metrics = supplMetrics
                break
            }
        }
        
        
        // Need to map the global index path to an index path relative to the target data source, because we're handling this method at the root of the data source tree. If I allowed subclasses to handle this, this wouldn't be necessary. But because of the way headers layer, it's more efficient to snapshot the section and find the metrics once.
        let local = localIndexPath(forGlobalIndexPath: indexPath)
        
        let view = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: metrics.reuseIdentifier, forIndexPath: indexPath) as UICollectionReusableView
        
        if let configure = metrics.configureView {
            configure(view: view, dataSource: dataSource, indexPath: local)
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
