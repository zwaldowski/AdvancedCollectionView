//
//  ComposedDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/29/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

/// A data source that maps between multiple child data sources. Child data sources may have multiple sections. Load content messages will be sent to all child data sources.
public class ComposedDataSource: DataSource, DataSourceContainer {
    
    private var mappings = OrderedDictionary<DataSource, ComposedMapping>()
    
    private var sectionDataSources = [DataSource]()
    
    /// Add a data source to the data source.
    public func add(#dataSource: DataSource) {
        assert(mappings[dataSource] == nil, "tried to add data source more than once: \(dataSource)")
        
        dataSource.container = self
        
        mappings.append(dataSource, ComposedMapping())
        updateMappings()
        if let sections = mappings[dataSource]?.globalSections(forNumberOfSections: dataSource.numberOfSections) {
            notifySectionsInserted(sections)
        }
    }
    
    /// Remove the specified data source from this data source.
    public func remove(#dataSource: DataSource) {
        let mapping = mappings.removeValueForKey(dataSource)
        assert(mappings[dataSource] != nil, "tried to remove data source not contained: \(dataSource)")

        dataSource.container = nil
        
        let removedSections = mapping?.globalSections(forNumberOfSections: dataSource.numberOfSections)
        updateMappings()
        if let sections = removedSections {
            notifySectionsRemoved(sections)
        }
    }
    
    /// Clear the collection of data sources.
    public func removeAllDataSources() {
        for (dataSource, _) in mappings {
            if dataSource.container === self {
                dataSource.container = nil
            }
        }
        
        mappings.removeAll()
    }
    
    // MARK: Private

    private func updateMappings() {
        sectionDataSources.removeAll(keepCapacity: true)

        for (dataSource, var mapping) in mappings {
            let sectionCount = sectionDataSources.count
            let newEndSection = mapping.updateMappings(startingWithGlobalSection: sectionCount, dataSource: dataSource)
            
            sectionDataSources += Repeat(count: newEndSection - sectionCount, repeatedValue: dataSource)
            
            mappings.updateValue(mapping, forKey: dataSource)
        }
    }
    
    // MARK: Overrides
    
    public override var numberOfSections: Int {
        updateMappings()
        return sectionDataSources.count
    }
    
    public override func childDataSource(forGlobalIndexPath indexPath: NSIndexPath) -> (DataSource, NSIndexPath) {
        let dataSource = sectionDataSources[indexPath[0]]
        let localIndexPath = mappings[dataSource]?.localIndexPath(forGlobalIndexPath: indexPath)
        return (dataSource, localIndexPath ?? indexPath)
    }
    
    public override func snapshotMetrics(#section: Section) -> SectionMetrics {
        var orig = super.snapshotMetrics(section: section)
        
        switch section {
        case .Global:
            break
        case .Index(let idx):
            let dataSource = sectionDataSources[idx]
            if let localSection = mappings[dataSource]?.localSection(forGlobalSection: idx) {
                let childMetrics = dataSource.snapshotMetrics(section: .Index(localSection))
                
                orig.apply(metrics: childMetrics)
            }
        }

        return orig
    }
    
    public override func registerReusableViews(#collectionView: UICollectionView) {
        super.registerReusableViews(collectionView: collectionView)
        
        for (dataSource, _) in mappings {
            dataSource.registerReusableViews(collectionView: collectionView)
        }
    }
    
    private func map(globalIndexPath indexPath: NSIndexPath, collectionView: UICollectionView) -> (UICollectionView!, DataSource, NSIndexPath) {
        if indexPath.length == 1 {
            return (collectionView, self, indexPath)
        }
        
        let dataSource = sectionDataSources[indexPath[0]]
        if let mapping = mappings[dataSource] {
            let wrapper = unsafeBitCast(ComposedViewWrapper(collectionView: collectionView, mapping: mapping), UICollectionView.self)
            let localIndexPath = mapping.localIndexPath(forGlobalIndexPath: indexPath)
            return (wrapper, dataSource, localIndexPath)
        } else {
            return (collectionView, self, indexPath)
        }
    }
    
    private func map(globalSection index: Int, collectionView: UICollectionView) -> (UICollectionView!, DataSource, Int) {
        let dataSource = sectionDataSources[index]
        if let mapping = mappings[dataSource] {
            let wrapper = unsafeBitCast(ComposedViewWrapper(collectionView: collectionView, mapping: mapping), UICollectionView.self)
            let localSection = mapping.localSection(forGlobalSection: index)
            return (wrapper, dataSource, localSection)
        } else {
            return (collectionView, self, index)
        }
    }
    
    // MARK: Loading state
    
    private var aggregateLoadingState: LoadingState!
    
    private func updateLoadingState() {
        var loading = 0, refreshing = 0, error = 0, loaded = 0, noContent = 0
        var currentError: NSError!

        var loadingStates = lazy(mappings).map { (dataSource, _) -> LoadingState in
            dataSource.loadingState
        }.array
        loadingStates.append(super.loadingState)
        
        for state in loadingStates {
            switch state {
            case .Initial:
                break
            case .Loading:
                ++loading
            case .Refreshing:
                ++refreshing
            case .Loaded:
                ++loaded
            case .NoContent:
                ++noContent
            case .Error(let err):
                if currentError == nil {
                    currentError = err
                }
                ++error
            }
        }

        if loading > 0 {
            aggregateLoadingState = .Loading
        } else if refreshing > 0 {
            aggregateLoadingState = .Refreshing
        } else if error > 0 {
            aggregateLoadingState = .Error(currentError)
        } else if noContent > 0 {
            aggregateLoadingState = .NoContent
        } else if loaded > 0 {
            aggregateLoadingState = .Loaded
        } else {
            aggregateLoadingState = .Initial
        }
    }
    
    override public var loadingState: LoadingState {
        get {
            if aggregateLoadingState == nil {
                updateLoadingState()
            }
            return aggregateLoadingState
        }
        
        set {
            aggregateLoadingState = nil
            super.loadingState = newValue
            updateLoadingState()
        }
    }
    
    public override func loadContent() {
        for (dataSource, _) in mappings {
            dataSource.loadContent()
        }
    }
    
    public override func resetContent() {
        aggregateLoadingState = nil
        
        super.resetContent()
        
        for (dataSource, _) in mappings {
            dataSource.resetContent()
        }
    }
    
    // MARK: DataSourceContainer
    
    public func dataSourceWillPerform(dataSource: DataSource, sectionAction: SectionAction) {
        switch sectionAction {
        case .Insert(let indexes, let direction):
            updateMappings()
            if let sections = mappings[dataSource]?.globalSections(forLocalSections: indexes) {
                notifySectionsInserted(sections, direction: direction)
            }
        case .Remove(let indexes, let direction):
            let sections = mappings[dataSource]?.globalSections(forLocalSections: indexes)
            updateMappings()
            if let sections = sections {
                notifySectionsRemoved(sections, direction: direction)
            }
        case .Reload(let indexes):
            updateMappings()
            if let sections = mappings[dataSource]?.globalSections(forLocalSections: indexes) {
                notifySectionsReloaded(sections)
            }
        case .Move(let from, let to, let direction):
            updateMappings()
            if let mapping = mappings[dataSource] {
                let globalOld = mapping.globalSection(forLocalSection: from)
                let globalNew = mapping.globalSection(forLocalSection: to)
                notifySectionsMoved(from: globalOld, to: globalNew, direction: direction)
            }
        default:
            notify(sectionAction: sectionAction)
        }
        
    }
    
    public func dataSourceWillPerform(dataSource: DataSource, itemAction: ItemAction) {
        switch itemAction {
        case .Insert(let indexPaths):
            if let global = mappings[dataSource]?.globalIndexPaths(forLocalIndexPaths: indexPaths) {
                notifyItemsInserted(global)
            }
        case .Remove(let indexPaths):
            if let global = mappings[dataSource]?.globalIndexPaths(forLocalIndexPaths: indexPaths) {
                notifyItemsRemoved(global)
            }
        case .Reload(let indexPaths):
            if let global = mappings[dataSource]?.globalIndexPaths(forLocalIndexPaths: indexPaths) {
                notifyItemsReloaded(global)
            }
        case .Move(let from, let to):
            if let mapping = mappings[dataSource] {
                let globalFrom = mapping.globalIndexPath(forLocalIndexPath: from)
                let globalTo = mapping.globalIndexPath(forLocalIndexPath: to)
                notifyItemMoved(from: globalFrom, to: globalTo)
            }
        case .WillLoad:
            updateLoadingState()
            notifyWillLoadContent()
        case .DidLoad(let error):
            let oldShowingPlaceholder = shouldDisplayPlaceholder
            updateLoadingState()
            
            // We were showing the placehoder and now we're not
            if oldShowingPlaceholder && shouldDisplayPlaceholder {
                notifyBatchUpdate {
                    self.executePendingUpdates()
                }
            }
            
            notifyContentLoaded(error: error)
        default:
            notify(itemAction: itemAction)
        }
    }

    // MARK: UICollectionViewDataSource
    
    public override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // If we're showing the placeholder, ignore what the child data sources have to say about the number of items.
        if shouldDisplayPlaceholder { return 0 }

        updateMappings()
        
        let (wrapper, dataSource, localSection) = map(globalSection: section, collectionView: collectionView)
        
        let numberOfSections = dataSource.numberOfSectionsInCollectionView(wrapper)
        assert(localSection < numberOfSections, "local section is out of bounds for composed data source")
        
        return dataSource.collectionView(wrapper, numberOfItemsInSection: localSection)
    }
    
    public override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath globalIndexPath: NSIndexPath) -> UICollectionViewCell {
        let (wrapper, dataSource, indexPath) = map(globalIndexPath: globalIndexPath, collectionView: collectionView)

        return dataSource.collectionView(wrapper, cellForItemAtIndexPath: indexPath)
    }
    
    // MARK: CollectionViewDataSourceGridLayout
    
    public override func sizeFittingSize(size: CGSize, itemAtIndexPath globalIndexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize {
        let (wrapper, dataSource, indexPath) = map(globalIndexPath: globalIndexPath, collectionView: collectionView)
        
        return dataSource.sizeFittingSize(size, itemAtIndexPath: indexPath, collectionView: wrapper)
    }
    
    public override func sizeFittingSize(size: CGSize, supplementaryElementOfKind kind: String, indexPath globalIndexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize {
        let (wrapper, dataSource, indexPath) = map(globalIndexPath: globalIndexPath, collectionView: collectionView)
        
        return dataSource.sizeFittingSize(size, supplementaryElementOfKind: kind, indexPath: indexPath, collectionView: wrapper)
    }
    
}
