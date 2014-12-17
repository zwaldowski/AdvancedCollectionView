//
//  DataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit
import Swift

public protocol DataSourcePresenter: class {
    
    /// Is this data source "hidden" by a placeholder either of its own or from an enclosing data source. Use this to determine whether to report that there are no items in your data source while loading.
    var isObscuredByPlaceholder: Bool { get }
    
    func dataSourceDidInsertItems(dataSource: DataSource, indexPaths: [NSIndexPath])
    func dataSourceDidRemoveItems(dataSource: DataSource, indexPaths: [NSIndexPath])
    func dataSourceDidReloadItems(dataSource: DataSource, indexPaths: [NSIndexPath])
    func dataSourceDidMoveItem(dataSource: DataSource, from: NSIndexPath, to: NSIndexPath)
    
    func dataSourceDidInsertSections(dataSource: DataSource, indexes: NSIndexSet, direction: SectionOperationDirection)
    func dataSourceDidRemoveSections(dataSource: DataSource, indexes: NSIndexSet, direction: SectionOperationDirection)
    func dataSourceDidReloadSections(dataSource: DataSource, indexes: NSIndexSet)
    func dataSourceDidMoveSection(dataSource: DataSource, from: Int, to: Int, direction: SectionOperationDirection)
    
    func dataSourceDidReloadData(dataSource: DataSource)
    func dataSourceDidReloadGlobalSection(dataSource: DataSource)
    func dataSourcePerformBatchUpdate(dataSource: DataSource, update: () -> (), completion: ((Bool) -> ())?)
    
    func dataSourceWillLoadContent(dataSource: DataSource)
    func dataSourceDidLoadContent(dataSource: DataSource, error: NSError?)
    
}

public class DataSource: NSObject {
    
    // MARK: Parent-child primitives
    
    public weak var presenter: DataSourcePresenter?
    
    var isRootDataSource: Bool {
        if let presenter = presenter {
            let casted: AnyObject = presenter as AnyObject
            return !(casted is DataSource)
        }
        return true
    }
    
    public func childDataSource(forSection section: Section) -> DataSource {
        return self
    }
    
    public func localIndexPath(forGlobalIndexPath global: NSIndexPath) -> NSIndexPath {
        return global
    }
    
    public let numberOfSections: Int = 1
    
    // MARK: Collection view interface
    
    public func registerReusableViews(#collectionView: UICollectionView) {
        for supplMetrics in snapshotMetrics(section: .Global).supplementaryViews {
            if supplMetrics.kind != UICollectionElementKindSectionHeader { continue }
            collectionView.registerClass(supplMetrics.viewType, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: supplMetrics.reuseIdentifier)
        }
        
        for idx in 0..<numberOfSections {
            for supplMetrics in snapshotMetrics(section: .Index(idx)).supplementaryViews {
                collectionView.registerClass(supplMetrics.viewType, forSupplementaryViewOfKind: supplMetrics.kind, withReuseIdentifier: supplMetrics.reuseIdentifier)
            }
        }
        
        collectionView.registerClass(AAPLCollectionPlaceholderView.self, forSupplementaryViewOfKind: ElementKindPlaceholder, withReuseIdentifier: NSStringFromClass(AAPLCollectionPlaceholderView.self))
    }
    
    // MARK: Loading
    private(set) public var loadingState: LoadingState = .Initial {
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
    
    public final func endLoading(#state: LoadingState, update: (() -> ())!) {
        loadingState = state
        
        if shouldDisplayPlaceholder {
            if let update = update {
                enqueuePendingUpdate(update)
            }
        } else {
            notifyBatchUpdate {
                // Run pending updates
                self.executePendingUpdates()
                if let update = update {
                    update()
                }
            }
        }
        
        var block: Block? = nil
        dispatch_semaphore_wait(whenLoadedLock, DISPATCH_TIME_FOREVER)
        swap(&whenLoaded, &block)
        dispatch_semaphore_signal(whenLoadedLock)
        if let block = block {
            block()
        }
        
        
        notifyContentLoaded(error: loadingState.error)
    }
    
    public final func loadContent(handler: () -> ()) {
        // TODO:
    }
    
    public func resetContent() { }
    
    public func loadContent() { }
    
    // MARK: Metrics
    
    private var sectionMetrics = [Section: SectionMetrics]()
    private var headers = [SupplementaryMetrics]()
    private var headersIndexesByKey = [String: (Int, SupplementaryMetrics)]()
    
    public var defaultMetrics: SectionMetrics! = SectionMetrics(defaultMetrics: ()) {
        didSet {
            if defaultMetrics == nil {
                defaultMetrics = SectionMetrics(defaultMetrics: ())
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
        case (_, .Index(0)):
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
    
    public func removeHeader(header: SupplementaryMetrics, forKey key: String) {
        if let index = headersIndexesByKey.indexForKey(key) {
            let (_, (arrayIdx, _)) = headersIndexesByKey[index]
            headersIndexesByKey.removeAtIndex(index)
            headers.removeAtIndex(arrayIdx)
        }
    }
    
    public func addSupplement(header: SupplementaryMetrics, forSection section: Section) {
        var metrics = sectionMetrics[section] ?? SectionMetrics()
        metrics.addSupplement(header)
        sectionMetrics[section] = metrics
    }
    
    // MARK: Placeholders
    
    private(set) public var placeholderView: AAPLCollectionPlaceholderView? = nil
    
    public var noContentTitle: String? = nil
    public var noContentMessage: String? = nil
    public var noContentImage: UIImage? = nil
    
    public var errorTitle: String? = nil
    public var errorMessage: String? = nil
    public var errorImage: UIImage? = nil
    
    public var isObscuredByPlaceholder: Bool {
        if shouldDisplayPlaceholder { return true }
        return presenter?.isObscuredByPlaceholder ?? false
    }
    
    private var shouldDisplayPlaceholder: Bool {
        switch (loadingState, errorMessage, errorTitle, noContentMessage, noContentTitle) {
        case (.Error, .Some, _, _, _), (.Error, _, .Some, _, _):
            // If we're in the error state & have an error message or title
            return true
        case (.NoContent, _, _, .Some, _), (.NoContent, _, _, _, .Some):
            return true
        case (.Loading, _, _, _, _):
            return true
        default:
            return false
        }
    }
    
    public func updatePlaceholder(notifyVisibility notify: Bool) {
        if let placeholderView = placeholderView {
            switch loadingState {
            case .Loading:
                placeholderView.showActivityIndicator(true)
            case .Loaded:
                placeholderView.showActivityIndicator(false)
            case .NoContent:
                placeholderView.showActivityIndicator(false)
                placeholderView.showPlaceholderWithTitle(noContentTitle, message: noContentMessage, image: noContentImage, animated: true)
            case .Error(let err):
                placeholderView.showActivityIndicator(false)
                placeholderView.showPlaceholderWithTitle(errorTitle, message: errorMessage, image: errorImage, animated: true)
            default:
                placeholderView.hidePlaceholderAnimated(true)
            }
        }
        
        if notify && (noContentTitle != nil || noContentMessage != nil || errorTitle != nil || errorMessage != nil) {
            notifySectionsReloaded(NSIndexSet(range: 0..<numberOfSections))
        }
    }
    
    func dequeuePlaceholderView(#collectionView: UICollectionView, indexPath: NSIndexPath) -> AAPLCollectionPlaceholderView {
        if placeholderView == nil {
            placeholderView = collectionView.dequeueReusableSupplementaryViewOfKind(ElementKindPlaceholder, withReuseIdentifier: NSStringFromClass(AAPLCollectionPlaceholderView.self), forIndexPath: indexPath) as? AAPLCollectionPlaceholderView
        }
        updatePlaceholder(notifyVisibility: false)
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
    
    public func notifyItemsInserted(indexPaths: [NSIndexPath]) {
        assertMainThread()
        
        if shouldDisplayPlaceholder {
            return enqueuePendingUpdate { [weak self] in
                self?.notifyItemsInserted(indexPaths)
                return
            }
        }
        
        presenter?.dataSourceDidInsertItems(self, indexPaths: indexPaths)
    }
    
    public func notifyItemsRemoved(indexPaths: [NSIndexPath]) {
        assertMainThread()
        
        if shouldDisplayPlaceholder {
            return enqueuePendingUpdate { [weak self] in
                self?.notifyItemsRemoved(indexPaths)
                return
            }
        }
        
        presenter?.dataSourceDidRemoveItems(self, indexPaths: indexPaths)
    }
    
    public func notifyItemsReloaded(indexPaths: [NSIndexPath]) {
        assertMainThread()
        
        if shouldDisplayPlaceholder {
            return enqueuePendingUpdate { [weak self] in
                self?.notifyItemsReloaded(indexPaths)
                return
            }
        }
        
        presenter?.dataSourceDidReloadItems(self, indexPaths: indexPaths)
    }
    
    public func notifyItemMoved(#from: NSIndexPath, to: NSIndexPath) {
        assertMainThread()
        
        if shouldDisplayPlaceholder {
            return enqueuePendingUpdate { [weak self] in
                self?.notifyItemMoved(from: from, to: to)
                return
            }
        }
        
        presenter?.dataSourceDidMoveItem(self, from: from, to: to)
    }
    
    public func notifySectionsInserted(indexSet: NSIndexSet, direction: SectionOperationDirection = .None) {
        assertMainThread()
        
        presenter?.dataSourceDidInsertSections(self, indexes: indexSet, direction: direction)
    }
    
    public func notifySectionsRemoved(indexSet: NSIndexSet, direction: SectionOperationDirection = .None) {
        assertMainThread()
        
        presenter?.dataSourceDidRemoveSections(self, indexes: indexSet, direction: direction)
    }
    
    public func notifySectionsReloaded(indexSet: NSIndexSet) {
        assertMainThread()
        
        presenter?.dataSourceDidReloadSections(self, indexes: indexSet)
    }
    
    public func notifySectionsMoved(#from: Int, to: Int, direction: SectionOperationDirection = .None) {
        assertMainThread()
        
        presenter?.dataSourceDidMoveSection(self, from: from, to: to, direction: direction)
    }
    
    public func notifyDidReloadData() {
        assertMainThread()
        
        presenter?.dataSourceDidReloadData(self)
    }
    
    public func notifyDidReloadGlobalSection() {
        assertMainThread()
        
        presenter?.dataSourceDidReloadGlobalSection(self)
    }
    
    public func notifyBatchUpdate(update: () -> (), completion: ((Bool) -> ())? = nil) {
        assertMainThread()
        
        if let presenter = presenter {
            presenter.dataSourcePerformBatchUpdate(self, update: update, completion: completion)
        } else {
            update()
            if let completion = completion {
                completion(true)
            }
        }
    }
    
    public func notifyContentLoaded(#error: NSError?) {
        assertMainThread()
        
        presenter?.dataSourceDidLoadContent(self, error: error)
    }
    
    public func notifyWillLoadContent() {
        assertMainThread()
        
        presenter?.dataSourceWillLoadContent(self)
    }
    
}

// MARK: SequenceType

extension DataSource: SequenceType {
    
    public func generate() -> GeneratorOf<Section> {
        var includedGlobal = false
        var base = map(lazy(0..<numberOfSections), {
            Section.Index($0)
        }).generate()
        
        return GeneratorOf {
            if includedGlobal {
                return base.next()
            }
            
            includedGlobal = true
            return .Global
        }
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
        
        let (section, item, dataSource) = info(indexPath: indexPath)
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
    
    public func canEditItem(atIndexPath indexPath: NSIndexPath, collectionView: UICollectionView) -> Bool {
        return false
    }
    
    public func canMoveItem(atIndexPath indexPath: NSIndexPath, collectionView: UICollectionView) -> Bool {
        return false
    }
    
    public func canMoveItem(fromIndexPath indexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath, collectionView: UICollectionView) -> Bool {
        return false
    }
    
    public func moveItem(from indexPath: NSIndexPath, to destinationIndexPath: NSIndexPath, collectionView: UICollectionView) {
        fatalError("This method must be overridden in a subclass")
    }
    
}

 