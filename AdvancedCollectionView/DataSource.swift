//
//  DataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

public class DataSource: NSObject, UICollectionViewDataSource, MetricsProviderLegacy {
    
    /// The title of this data source. This value is used to populate section headers and the segmented control tab.
    public final var title: String?
    
    /// The logical number of sections presented by this data source.
    public var numberOfSections: Int {
        return 1
    }
    
    // MARK: Parent-child primitives
    
    public weak var container: DataSourceContainer?
    
    public func localSection(global section: Int) -> Int {
        return container?.localSection(global: section) ?? section
    }
    
    public func globalSection(local section: Int) -> Int {
        return container?.globalSection(local: section) ?? section
    }
    
    public func containedDataSource(forSection section: Int) -> DataSource {
        return self
    }
    
    var isRootDataSource: Bool {
        if let container = container {
            let casted: AnyObject = container as AnyObject
            return !(casted is DataSource)
        }
        return true
    }
    
    // MARK: Collection view interface
    
    public func registerReusableViews(#collectionView: UICollectionView) {
        for supplMetrics in snapshotSupplements(section: .Global) {
            if supplMetrics.kind != SupplementKind.Header.rawValue { continue }
            collectionView.register(typeForSupplement: supplMetrics.viewType, ofKind: SupplementKind.Header, reuseIdentifier: supplMetrics.reuseIdentifier)
        }
        
        for idx in 0..<numberOfSections {
            for supplMetrics in snapshotSupplements(section: .Index(idx)) {
                collectionView.register(typeForSupplement: supplMetrics.viewType, ofRawKind: supplMetrics.kind, reuseIdentifier: supplMetrics.reuseIdentifier)
            }
        }
        
        collectionView.register(typeForSupplement: CollectionPlaceholderView.self, ofKind: SupplementKind.Placeholder)
    }
    
    // MARK: Loading
    
    private var loadingInstance: Loader? = nil
    
    public var loadingState: LoadingState = .Initial {
        didSet {
            switch loadingState {
            case .Loading, .Loaded, .NoContent, .Error:
                updatePlaceholder(notifyVisibility: true)
            default:
                break
            }
        }
    }
    
    private var loadingDebounce: Async?
    public func setNeedsLoadContent() {
        loadingDebounce?.cancel()
        loadingDebounce = Async.main(loadContent)
    }
    
    public final func beginLoading() {
        switch loadingState {
        case .Initial, .Loading:
            loadingState = .Loading
        default:
            loadingState = .Refreshing
        }
        
        notifyWillLoadContent()
    }
    
    private let whenLoadedLock = dispatch_semaphore_create(1)
    private var whenLoaded: Block? = nil
    
    public final func whenLoaded(completion: Block) {
        dispatch_semaphore_wait(whenLoadedLock, DISPATCH_TIME_FOREVER)
        if let oldCompletion = whenLoaded {
            whenLoaded = {
                oldCompletion()
                completion()
            }
        } else {
            whenLoaded = completion
        }
        dispatch_semaphore_signal(whenLoadedLock)
    }
    
    public final func endLoading(#state: LoadingState, update: Block?) {
        loadingState = state
        
        if shouldDisplayPlaceholder {
            if let update = update {
                enqueuePendingUpdate(update)
            }
        } else {
            notifyBatchUpdate({
                // Run pending updates
                self.executePendingUpdates()
                update?()
            }, completion: nil)
        }
        
        var block: Block? = nil
        dispatch_semaphore_wait(whenLoadedLock, DISPATCH_TIME_FOREVER)
        swap(&whenLoaded, &block)
        dispatch_semaphore_signal(whenLoadedLock)
        block?()
        
        notifyContentLoaded(error: loadingState.error)
    }
    
    public final func startLoadingContent(handler: Loader -> ()) {
        beginLoading()
        
        let newLoading = Loader{ (newState, update) in
            if let state = newState {
                self.endLoading(state: state) {
                    update?()
                    return
                }
            }
        }
        
        // Tell previous loading instance it's no longer current and remember this loading instance
        loadingInstance?.isCurrent = false
        loadingInstance = newLoading
        
        // Call the provided block to actually do the load
        handler(newLoading)
    }
    
    public func resetContent() {
        loadingState = .Initial
        loadingInstance?.isCurrent = false
    }
    
    public func loadContent() { }
    
    // MARK: Metrics
    
    /// Metrics common to everything contained by the data source
    public var defaultMetrics: SectionMetrics = SectionMetrics()

    private typealias SectionEntry = (metrics: SectionMetrics, supplements: [SupplementaryMetrics])
    private var perSectionAttributes = [Section: SectionEntry]()
    
    private func updateAttributes(entry: SectionEntry, forSection section: Section) {
        perSectionAttributes[section] = entry
        
        switch section {
        case .Global:
            notifyDidReloadGlobalSection()
        case .Index(let sectionIndex):
            notifySectionsReloaded(NSIndexSet(index: sectionIndex))
        }
    }
    
    public subscript(section: Section) -> SectionMetrics {
        get {
            return perSectionAttributes[section]?.metrics ?? SectionMetrics()
        }
        set(metrics) {
            let currentSupplements = supplements(section)
            let entry = (metrics, currentSupplements)
            updateAttributes(entry, forSection: section)
        }
    }
    
    public func supplements(section: Section) -> [SupplementaryMetrics] {
        return perSectionAttributes[section]?.supplements ?? []
    }
    
    public func setSupplements(supplements: [SupplementaryMetrics], forSection section: Section) {
        let currentMetrics = self[section] ?? SectionMetrics()
        let entry = (currentMetrics, supplements)
        updateAttributes(entry, forSection: section)
    }
    
    // MARK: Headers
    
    private var headers = OrderedDictionary<String, SupplementaryMetrics>()

    public func header(forKey key: String) -> SupplementaryMetrics? {
        return headers[key]
    }
    
    public func addHeader(header: SupplementaryMetrics, forKey key: String) {
        headers[key] = header
    }
    
    public func updateHeader(header: SupplementaryMetrics, forKey key: String) -> SupplementaryMetrics? {
        return headers.updateValue(header, forKey: key)
    }
    
    public func removeHeader(forKey key: String) {
        headers.removeValueForKey(key)
    }
    
    // MARK: Placeholders
    
    private var placeholderView: CollectionPlaceholderView!
    
    public var emptyContent = PlaceholderContent(title: nil, message: nil, image: nil)
    public var errorContent = PlaceholderContent(title: nil, message: nil, image: nil)
    
    public var isObscuredByPlaceholder: Bool {
        if shouldDisplayPlaceholder { return true }
        return container?.isObscuredByPlaceholder ?? false
    }
    
    public var shouldDisplayPlaceholder: Bool {
        switch (loadingState, emptyContent.isEmpty, errorContent.isEmpty) {
        case (.NoContent, false, _):
            return true
        case (.Error, _, false):
            // If we're in the error state & have an error message or title
            return true
        case (.Loading, _, _):
            return true
        default:
            return false
        }
    }
    
    public func updatePlaceholder(_ placeholderView: CollectionPlaceholderView? = nil, notifyVisibility notify: Bool = false) {
        if let placeholderView = placeholderView {
            switch loadingState {
            case .Loading:
                placeholderView.showsActivityIndicator = true
            case .Loaded:
                placeholderView.showsActivityIndicator = false
            case .NoContent:
                placeholderView.showsActivityIndicator = false
                placeholderView.showPlaceholder(content: emptyContent, animated: true)
            case .Error(let err):
                placeholderView.showsActivityIndicator = false
                placeholderView.showPlaceholder(content: errorContent, animated: true)
            default:
                placeholderView.hidePlaceholder(animated: true)
            }
        }
        
        if notify && (!emptyContent.isEmpty || !errorContent.isEmpty) {
            notifySectionsReloaded(NSIndexSet(range: 0..<numberOfSections))
        }
    }
    
    public func dequeuePlaceholderView(#collectionView: UICollectionView, indexPath: NSIndexPath) -> CollectionPlaceholderView {
        if placeholderView == nil {
            placeholderView = collectionView.dequeue(supplementOfType: CollectionPlaceholderView.self, ofKind: SupplementKind.Placeholder, indexPath: indexPath)
        }
        updatePlaceholder(placeholderView, notifyVisibility: false)
        return placeholderView
    }
    
    // MARK: Notifications
    
    private var pendingUpdate: (() -> ())? = nil
    
    func executePendingUpdates() {
        assertMainThread()
        
        let update = pendingUpdate
        pendingUpdate = nil
        if let update = update {
            update()
        }
    }
    
    public func enqueuePendingUpdate(update: () -> ()) {
        if let oldUpdate = pendingUpdate {
            pendingUpdate = {
                oldUpdate()
                update()
            }
        } else {
            pendingUpdate = update
        }
    }
    
    public func notify(#sectionAction: SectionAction) {
        assertMainThread()
        
        container?.dataSourceWillPerform(self, sectionAction: sectionAction)
    }
    
    public func notify(#itemAction: ItemAction) {
        assertMainThread()
        
        switch (itemAction, shouldDisplayPlaceholder, container) {
        case (.Insert, true, _), (.Remove, true, _), (.Reload, true, _), (.Move, true, _):
            enqueuePendingUpdate { [weak self] in
                self?.notify(itemAction: itemAction)
                return
            }
        case (.BatchUpdate(let update, let completion), _, .None):
            update()
            completion?(true)
        case let (_, _, .Some(container)):
            container.dataSourceWillPerform(self, itemAction: itemAction)
        default: break
        }
    }
    
    // MARK: Convenience notifications
    
    public func notifySectionsInserted<T: SequenceType where T.Generator.Element == Int>(sections: T, direction: SectionOperationDirection = .Default) {
        notify(sectionAction: .Insert(NSIndexSet(indexes: sections), direction: direction))
    }
    
    public func notifySectionsRemoved<T: SequenceType where T.Generator.Element == Int>(sections: T, direction: SectionOperationDirection = .Default) {
        notify(sectionAction: .Remove(NSIndexSet(indexes: sections), direction: direction))
    }
    
    public func notifySectionsReloaded<T: SequenceType where T.Generator.Element == Int>(sections: T) {
        notify(sectionAction: .Reload(NSIndexSet(indexes: sections)))
    }
    
    public func notifySectionsMoved(#from: Int, to: Int, direction: SectionOperationDirection = .Default) {
        notify(sectionAction: .Move(from: from, to: to, direction: direction))
    }
    
    public func notifyDidReloadGlobalSection() {
        notify(sectionAction: .ReloadGlobal)
    }
    
    public func notifyItemsInserted(indexPaths: [NSIndexPath]) {
        notify(itemAction: .Insert(indexPaths))
    }
    
    public func notifyItemsInserted<T: SequenceType where T.Generator.Element == Int>(items: T, inSection section: Int) {
        let indexPaths = map(items) { NSIndexPath(section, $0) }
        notify(itemAction: .Insert(indexPaths))
    }
    
    public func notifyItemsRemoved(indexPaths: [NSIndexPath]) {
        notify(itemAction: .Remove(indexPaths))
    }
    
    public func notifyItemsRemoved<T: SequenceType where T.Generator.Element == Int>(items: T, inSection section: Int) {
        let indexPaths = map(items) { NSIndexPath(section, $0) }
        notify(itemAction: .Remove(indexPaths))
    }
    
    public func notifyItemsReloaded(indexPaths: [NSIndexPath]) {
        notify(itemAction: .Reload(indexPaths))
    }
    
    public func notifyItemsReloaded<T: SequenceType where T.Generator.Element == Int>(items: T, inSection section: Int) {
        let indexPaths = map(items) { NSIndexPath(section, $0) }
        notify(itemAction: .Reload(indexPaths))
    }
    
    public func notifyItemMoved(#from: NSIndexPath, to: NSIndexPath) {
        notify(itemAction: .Move(from: from, to: to))
    }
    
    public func notifyItemsMoved<T: SequenceType where T.Generator.Element == ItemAction.IndexMove>(items: T, inSection section: Int) {
        for (oldIndex, newIndex) in items {
            notifyItemMoved(from: NSIndexPath(section, oldIndex), to: NSIndexPath(section, newIndex))
        }
    }
    
    public func notifyDidReloadData() {
        notify(itemAction: .ReloadAll)
    }
    
    public func notifyBatchUpdate(update: () -> (), completion: ((Bool) -> ())? = nil) {
        notify(itemAction: .BatchUpdate(update: update, completion: completion))
    }
    
    public func notifyWillLoadContent() {
        notify(itemAction: .WillLoad)
    }
    
    public func notifyContentLoaded(#error: NSError?) {
        notify(itemAction: .DidLoad(error))
    }
    
    // MARK: UICollectionViewDataSource
    
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
        if kind == SupplementKind.Placeholder.rawValue {
            return dequeuePlaceholderView(collectionView: collectionView, indexPath: indexPath)
        }
        
        // Need to map the global index path to an index path relative to the target data source, because we're handling this method at the root of the data source tree. If I allowed subclasses to handle this, this wouldn't be necessary. But because of the way headers layer, it's more efficient to snapshot the section and find the metrics once.

        let (section, localItem, dataSource, localIndexPath) = { () -> (Section, Int, DataSource, NSIndexPath) in
            if indexPath.length == 1 {
                return (.Global, indexPath[0], self, indexPath)
            }
            
            let section = indexPath[0]
            let item = indexPath[1]
            let dataSource = self.containedDataSource(forSection: section)
            let localSection = dataSource.localSection(global: section)
            let localIndexPath = NSIndexPath(localSection, item)
            return (.Index(section), item, dataSource, localIndexPath)
        }()
        
        let supplements = lazy(snapshotSupplements(section: section)).filter {
            $0.kind == kind
        }
        
        for (i, metrics) in enumerate(supplements) {
            if i != localItem { continue }
            
            let view = collectionView.dequeue(supplementOfType: metrics.viewType, ofRawKind: kind, indexPath: indexPath, reuseIdentifier: metrics.reuseIdentifier)
            metrics.configureView(view: view, dataSource: dataSource, indexPath: localIndexPath)
            return view
        }
        
        fatalError("Could not locate metrics for the specified supplement. Either the data source is misconfigured or you have discovered a bug in the grid layout.")
    }
    
    // MARK: CollectionViewDataSourceGridLayout

    public func snapshotMetrics(#section: Section) -> SectionMetrics {
        var metrics = isRootDataSource ? SectionMetrics.defaultMetrics : SectionMetrics()
        
        metrics.apply(metrics: defaultMetrics)
        metrics.apply(metrics: self[section])
        
        switch (isRootDataSource, section) {
        case (false, .Index(0)):
            metrics.hasPlaceholder = shouldDisplayPlaceholder
        default: break
        }
        
        if metrics.backgroundColor == nil {
            metrics.backgroundColor = UIColor.whiteColor()
        }
        
        return metrics
    }
    
    public func snapshotSupplements(#section: Section) -> [SupplementaryMetrics] {
        switch (isRootDataSource, section) {
        case (true, .Global):
            return map(headers) { $0.1 }
        case (false, .Index(0)):
            // We need to handle global headers for section 0
            return map(headers) { $0.1 } + supplements(section)
        default:
            return supplements(section)
        }
    }
    
    // MARK: MetricsProviderLegacy
    
    public func sizeFittingSize(size: CGSize, itemAtIndexPath indexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize {
        let cell = self.collectionView(collectionView, cellForItemAtIndexPath: indexPath)
        let fittingSize = cell.preferredLayoutSize(fittingSize: size)
        cell.removeFromSuperview() // force it to get put in the reuse pool now
        return fittingSize
    }
    
    public func sizeFittingSize(size: CGSize, supplementaryElementOfKind kind: String, indexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize {
        let cell = self.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, atIndexPath: indexPath)
        let fittingSize = cell.preferredLayoutSize(fittingSize: size)
        cell.removeFromSuperview() // force it to get put in the reuse pool now
        return fittingSize
    }
    
}
