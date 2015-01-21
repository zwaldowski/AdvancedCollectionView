//
//  DataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

public class DataSource: NSObject {
    
    // MARK: Parent-child primitives
    
    public weak var container: DataSourceContainer?
    
    var isRootDataSource: Bool {
        if let container = container {
            let casted: AnyObject = container as AnyObject
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
        return container?.isObscuredByPlaceholder ?? false
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
        
        container?.dataSourceDidInsertItems(self, indexPaths: indexPaths)
    }
    
    public func notifyItemsRemoved(indexPaths: [NSIndexPath]) {
        assertMainThread()
        
        if shouldDisplayPlaceholder {
            return enqueuePendingUpdate { [weak self] in
                self?.notifyItemsRemoved(indexPaths)
                return
            }
        }
        
        container?.dataSourceDidRemoveItems(self, indexPaths: indexPaths)
    }
    
    public func notifyItemsReloaded(indexPaths: [NSIndexPath]) {
        assertMainThread()
        
        if shouldDisplayPlaceholder {
            return enqueuePendingUpdate { [weak self] in
                self?.notifyItemsReloaded(indexPaths)
                return
            }
        }
        
        container?.dataSourceDidReloadItems(self, indexPaths: indexPaths)
    }
    
    public func notifyItemMoved(#from: NSIndexPath, to: NSIndexPath) {
        assertMainThread()
        
        if shouldDisplayPlaceholder {
            return enqueuePendingUpdate { [weak self] in
                self?.notifyItemMoved(from: from, to: to)
                return
            }
        }
        
        container?.dataSourceDidMoveItem(self, from: from, to: to)
    }
    
    public func notifySectionsInserted(indexSet: NSIndexSet, direction: SectionOperationDirection = .Default) {
        assertMainThread()
        
        container?.dataSourceWillInsertSections(self, indexes: indexSet, direction: direction)
    }
    
    public func notifySectionsRemoved(indexSet: NSIndexSet, direction: SectionOperationDirection = .Default) {
        assertMainThread()
        
        container?.dataSourceWillRemoveSections(self, indexes: indexSet, direction: direction)
    }
    
    public func notifySectionsReloaded(indexSet: NSIndexSet) {
        assertMainThread()
        
        container?.dataSourceDidReloadSections(self, indexes: indexSet)
    }
    
    public func notifySectionsMoved(#from: Int, to: Int, direction: SectionOperationDirection = .Default) {
        assertMainThread()
        
        container?.dataSourceWillMoveSection(self, from: from, to: to, direction: direction)
    }
    
    public func notifyDidReloadData() {
        assertMainThread()
        
        container?.dataSourceDidReloadData(self)
    }
    
    public func notifyDidReloadGlobalSection() {
        assertMainThread()
        
        container?.dataSourceDidReloadGlobalSection(self)
    }
    
    public func notifyBatchUpdate(update: () -> (), completion: ((Bool) -> ())? = nil) {
        assertMainThread()
        
        if let container = container {
            container.dataSourcePerformBatchUpdate(self, update: update, completion: completion)
        } else {
            update()
            if let completion = completion {
                completion(true)
            }
        }
    }
    
    public func notifyContentLoaded(#error: NSError?) {
        assertMainThread()
        
        container?.dataSourceDidLoadContent(self, error: error)
    }
    
    public func notifyWillLoadContent() {
        assertMainThread()
        
        container?.dataSourceWillLoadContent(self)
    }
    
}
