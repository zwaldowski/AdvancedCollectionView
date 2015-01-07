//
//  DataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

public class DataSource: NSObject, SequenceType, CollectionViewDataSourceGridLayout {
    
    /// The title of this data source. This value is used to populate section headers and the segmented control tab.
    public final var title: String?
    
    // MARK: Parent-child primitives
    
    public var numberOfSections: Int {
        return 1
    }
    
    public func childDataSource(forGlobalIndexPath indexPath: NSIndexPath) -> (DataSource, NSIndexPath) {
        return (self, indexPath)
    }
    
    // MARK: Parent-child utilities
    
    public weak var container: DataSourceContainer?
    
    var isRootDataSource: Bool {
        if let container = container {
            let casted: AnyObject = container as AnyObject
            return !(casted is DataSource)
        }
        return true
    }
    
    // MARK: Collection view interface
    
    public func registerReusableViews(#collectionView: UICollectionView) {
        for supplMetrics in snapshotMetrics(section: .Global).supplementaryViews {
            if supplMetrics.kind != SupplementKind.Header.rawValue { continue }
            collectionView.register(typeForSupplement: supplMetrics.viewType, ofKind: SupplementKind.Header)
        }
        
        for idx in 0..<numberOfSections {
            for supplMetrics in snapshotMetrics(section: .Index(idx)).supplementaryViews {
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
        loadingDebounce = async(Queue.mainQueue, loadContent)
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
            notifyBatchUpdate {
                // Run pending updates
                self.executePendingUpdates()
                update?()
            }
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
            if newState == nil { return }
            self.endLoading(state: newState!) {
                
                update?()
                return
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
    
    private var sectionMetrics = [Section: SectionMetrics]()
    private var headers = [SupplementaryMetrics]()
    private var headersIndexesByKey = [String: (Int, SupplementaryMetrics)]()
    
    public var defaultMetrics: SectionMetrics! = SectionMetrics.defaultMetrics {
        didSet {
            if defaultMetrics == nil {
                defaultMetrics = SectionMetrics.defaultMetrics
            }
        }
    }
    
    public subscript(section: Section) -> SectionMetrics? {
        get {
            return sectionMetrics[section]
        }
        set(metrics) {
            sectionMetrics[section] = metrics
            
            switch section {
            case .Global:
                notifyDidReloadGlobalSection()
            case .Index(let sectionIndex):
                notifySectionsReloaded(NSIndexSet(index: sectionIndex))
            }
        }
    }
    
    public func snapshotMetrics(#section: Section) -> SectionMetrics {
        var metrics = defaultMetrics
        if let submetrics = sectionMetrics[section] {
            metrics.apply(metrics: submetrics)
        }
        
        let isRoot = isRootDataSource
        switch (isRootDataSource, section) {
        case (true, .Global):
            metrics.supplementaryViews = headers
        case (false, .Index(0)):
            // We need to handle global headers and the placeholder view for section 0
            metrics.supplementaryViews = headers + metrics.supplementaryViews
            metrics.hasPlaceholder = shouldDisplayPlaceholder
        default: break
        }
        
        return metrics
    }
    
    // MARK: Headers
    
    public func header(forKey key: String) -> SupplementaryMetrics? {
        return headersIndexesByKey[key]?.1
    }
    
    public func addHeader(header: SupplementaryMetrics, forKey key: String) {
        headers.append(header)
        let index = headers.endIndex.predecessor()
        headersIndexesByKey[key] = (index, header)
    }
    
    public func updateHeader(header: SupplementaryMetrics, forKey key: String) {
        if let (idx, old) = headersIndexesByKey[key] {
            headersIndexesByKey[key] = (idx, header)
            headers[idx] = header
        } else {
            addHeader(header, forKey: key)
        }
    }
    
    public func removeHeader(forKey key: String) {
        if let index = headersIndexesByKey.indexForKey(key) {
            let (_, (arrayIdx, _)) = headersIndexesByKey[index]
            headersIndexesByKey.removeAtIndex(index)
            headers.removeAtIndex(arrayIdx)
        }
    }
    
    public func addSupplement(header: SupplementaryMetrics, forSection section: Section) {
        var metrics = sectionMetrics[section] ?? SectionMetrics()
        metrics.supplementaryViews.append(header)
        sectionMetrics[section] = metrics
    }
    
    // MARK: Placeholders
    
    private(set) public var placeholderView: CollectionPlaceholderView? = nil
    
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
    
    func dequeuePlaceholderView(#collectionView: UICollectionView, indexPath: NSIndexPath) -> CollectionPlaceholderView {
        if placeholderView == nil {
            placeholderView = collectionView.dequeue(supplementOfType: CollectionPlaceholderView.self, ofKind: SupplementKind.Placeholder, indexPath: indexPath)
        }
        updatePlaceholder(placeholderView, notifyVisibility: false)
        return placeholderView!
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
            if let completion = completion {
                completion(true)
            }
        default:
            container?.dataSourceWillPerform(self, itemAction: itemAction)
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
        
    // MARK: SequenceType
    
    public func generate() -> GeneratorOf<Section> {
        return Section.all(numberOfSections: numberOfSections)
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
        
        let view = collectionView.dequeue(supplementOfType: UICollectionReusableView.self, ofRawKind: kind, indexPath: indexPath, reuseIdentifier: metrics.reuseIdentifier)
        
        if let configure = metrics.configureView {
            configure(view: view, dataSource: dataSource, indexPath: localIndexPath)
        }
        
        return view
    }
    
    // MARK: CollectionViewDataSourceGridLayout
    
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
