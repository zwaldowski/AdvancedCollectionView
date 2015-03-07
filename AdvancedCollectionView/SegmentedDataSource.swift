//
//  SegmentedDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/27/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

/// A data source that switches among a number of child data sources.
public class SegmentedDataSource: DataSource, DataSourceContainer {
    
    /// Should the data source create a default header that allows switching between the data sources. Set to NO if switching is accomplished through some other means. Default value is YES.
    public var shouldDisplayDefaultHeader = true

    /// The collection of data sources contained within this segmented data source.
    private(set) public var dataSources = [DataSource]()
    
    /// Add a data source to the end of the collection. The `title` of `dataSource` will be used to populate a new segment in the control associated with this data source.
    public func add(#dataSource: DataSource) {
        let isEmpty = dataSources.isEmpty
        
        dataSources.append(dataSource)
        dataSource.container = self
        
        if isEmpty {
            selectedDataSource = dataSource
        }
    }
    
    /// Remove the data source from the collection.
    public func remove(#dataSource: DataSource) {
        if let ds = removeValue(&dataSources, dataSource) {
            if dataSource.container === self {
                dataSource.container = nil
            }
        }
    }
    
    /// Clear the collection of data sources.
    public func removeAllDataSources() {
        for dataSource in dataSources {
            if dataSource.container === self {
                dataSource.container = nil
            }
        }
        
        dataSources.removeAll()
        selectedDataSource = nil
    }
    
    // MARK: Selected data source
    
    private weak var _selectedDataSource: DataSource? = nil
    
    /// A reference to the selected data source.
    public weak var selectedDataSource: DataSource? {
        get { return _selectedDataSource }
        set { setSelectedDataSource(newValue, animated: false, onCompletion: nil) }
    }
    
    /// Set the selected data source with animation. By default, setting the selected data source is not animated.
    public func setSelectedDataSource(newDataSource: DataSource?, animated: Bool, onCompletion completion: ((Bool) -> ())? = nil) {
        if _selectedDataSource == newDataSource {
            completion?(true)
            return
        }
        
        if let dataSource = newDataSource {
            assert(contains(dataSources, dataSource), "selected data source must be contained in this data source")
        }
        
        let oldSectionsCount = _selectedDataSource?.numberOfSections ?? 0
        let newSectionsCount = newDataSource?.numberOfSections ?? 0
        
        let direction = animated ? { _ -> SectionOperationDirection in
            let oldIndex = self._selectedDataSource.map { find(self.dataSources, $0) }
            let newIndex = newDataSource.map { find(self.dataSources, $0) }
            switch (oldIndex, newIndex) {
            case (.Some(let left), .Some(let right)):
                return left < right ? .Right : .Left
            default:
                return .Default
            }
        }() : .Default
        
        willChangeValueForKey("selectedDataSource")
        _selectedDataSource = newDataSource
        didChangeValueForKey("selectedDataSource")
        
        let removedSections = NSIndexSet(range: 0..<oldSectionsCount)
        let insertedSections = NSIndexSet(range: 0..<newSectionsCount)
        
        // Update the sections all at once.
        notifyBatchUpdate({ () -> () in
            self.notifySectionsRemoved(removedSections, direction: direction)
            self.notifySectionsInserted(insertedSections, direction: direction)
        }, completion: completion)
        
        // If the newly selected data source has never been loaded, load it now
        if let dataSource = newDataSource {
            switch dataSource.loadingState {
            case .Initial:
                dataSource.setNeedsLoadContent()
            default: break
            }
        }
    }
    
    // MARK: Segmented control
    
    /// Call this method to configure a segmented control with the titles of the data sources. This method also sets the target & action of the segmented control to switch the selected data source.
    public func configureSegmentedControl(segmentedControl: UISegmentedControl) {
        segmentedControl.removeAllSegments()
        
        var selectedIndex = -1
        for (idx, dataSource) in enumerate(dataSources) {
            let title = dataSource.title ?? "NULL"
            segmentedControl.insertSegmentWithTitle(title, atIndex: idx, animated: false)
            
            if dataSource == selectedDataSource {
                selectedIndex = idx
            }
        }
        
        segmentedControl.addTarget(self, action: "selectedSegmentIndexChanged:", forControlEvents: UIControlEvents.ValueChanged)
        segmentedControl.selectedSegmentIndex = selectedIndex
    }
    
    @IBAction func selectedSegmentIndexChanged(sender: UISegmentedControl) {
        sender.userInteractionEnabled = false
        
        let dataSource = dataSources[sender.selectedSegmentIndex]
        setSelectedDataSource(dataSource, animated: true) { _ in
            sender.userInteractionEnabled = true
        }
    }
    
    private func segmentedControlHeader() -> SupplementaryMetrics {
        var header = SupplementaryMetrics(kind: SupplementKind.Header)
        header.measurement = .Estimate(48)
        header.shouldPin = true
        // Show this header regardless of whether there are items
        header.isVisibleWhileShowingPlaceholder = true
        header.configure { (view: SegmentedHeaderView, dataSource: SegmentedDataSource, indexPath) -> () in
            dataSource.configureSegmentedControl(view.segmentedControl)
        }
        
        return header
    }
    
    
    // MARK: Overrides
    
    public override var numberOfSections: Int {
        return selectedDataSource?.numberOfSections ?? 1
    }
    
    public override func containedDataSource(forSection section: Int) -> DataSource {
        return selectedDataSource?.containedDataSource(forSection: section) ?? self
    }
    
    public override func snapshotMetrics(#section: Section) -> SectionMetrics {
        let key = "SegmentedHeaderKey"
        let defaultHeader = header(forKey: key)
        switch (shouldDisplayDefaultHeader, defaultHeader) {
        case (true, .None):
            addHeader(segmentedControlHeader(), forKey: key)
        case (false, .Some):
            removeHeader(forKey: key)
        default:
            break
        }

        var enclosing = super.snapshotMetrics(section: section)
        if let metrics = selectedDataSource?.snapshotMetrics(section: section) {
            enclosing.apply(metrics: metrics)
        }
        return enclosing
    }
    
    public override func registerReusableViews(#collectionView: UICollectionView) {
        super.registerReusableViews(collectionView: collectionView)
        
        for dataSource in dataSources {
            dataSource.registerReusableViews(collectionView: collectionView)
        }
    }
    
    public override func loadContent() {
        // Only load the currently selected data source. Others will be loaded as necessary.
        selectedDataSource?.loadContent()
    }
    
    public override func resetContent() {
        for dataSource in dataSources {
            dataSource.resetContent()
        }
        
        super.resetContent()
    }
    
    // MARK: Placeholders
    
    public override var shouldDisplayPlaceholder: Bool {
        if super.shouldDisplayPlaceholder {
            return true
        }
        return selectedDataSource?.shouldDisplayPlaceholder ?? false
    }
    
    public override func updatePlaceholder(placeholderView: CollectionPlaceholderView?, notifyVisibility notify: Bool) {
        _selectedDataSource?.updatePlaceholder(placeholderView, notifyVisibility: notify)
    }
    
    public override var emptyContent: PlaceholderContent {
        get {
            if let child = selectedDataSource {
                return child.emptyContent
            } else {
                return super.emptyContent
            }
        }
        set {
            if let child = selectedDataSource {
                child.emptyContent = newValue
            } else {
                super.emptyContent = newValue
            }
        }
    }
    
    public override var errorContent: PlaceholderContent {
        get {
            if let child = selectedDataSource {
                return child.errorContent
            } else {
                return super.errorContent
            }
        }
        set {
            if let child = selectedDataSource {
                child.errorContent = newValue
            } else {
                super.errorContent = newValue
            }
        }
    }
    
    // MARK: UICollectionViewDataSource
    
    public override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if shouldDisplayPlaceholder { return 0 }
        return selectedDataSource?.collectionView(collectionView, numberOfItemsInSection: section) ?? 0
    }
    
    public override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        return selectedDataSource!.collectionView(collectionView, cellForItemAtIndexPath: indexPath)
    }
    
    // MARK: MetricsProviderLegacy
    
    public override func sizeFittingSize(size: CGSize, itemAtIndexPath indexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize {
        return selectedDataSource?.sizeFittingSize(size, itemAtIndexPath: indexPath, collectionView: collectionView) ?? size
    }

    // MARK: DataSourceContainer
    
    public func dataSourceWillPerform(dataSource: DataSource, sectionAction: SectionAction) {
        if dataSource != _selectedDataSource { return }
        notify(sectionAction: sectionAction)
    }
    
    public func dataSourceWillPerform(dataSource: DataSource, itemAction: ItemAction) {
        switch (selectedDataSource, itemAction) {
        case (let ds, _) where ds == dataSource:
            notify(itemAction: itemAction)
        case (_, .BatchUpdate(let update, let completion)):
            update();
            completion?(true)
        default: break
        }
    }
    
}

