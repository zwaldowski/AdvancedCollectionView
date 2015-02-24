//
//  GridLayout.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

public protocol MetricsProvider: class {
    
    /// Compute a flattened snapshot of the layout metrics associated with this and any child data sources.
    func snapshotMetrics(#section: Section) -> SectionMetrics
    
    /// Compute an ordered snapshot of the supplements associated with this and any child data sources.
    func snapshotSupplements(#section: Section) -> [SupplementaryMetrics]
    
}

public protocol MetricsProviderLegacy: MetricsProvider {
    
    /// Measure variable height cells. The goal here is to do the minimal necessary configuration to get the correct size information.
    func sizeFittingSize(size: CGSize, itemAtIndexPath indexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize
    
    /// Measure variable height supplements. The goal here is to do the minimal necessary configuration to get the correct size information.
    func sizeFittingSize(size: CGSize, supplementaryElementOfKind kind: String, indexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize
    
}

// MARK: -

private enum DecorationKind: String {
    case RowSeparator = "rowSeparator"
    case ColumnSeparator = "columnSeparator"
    case HeaderSeparator = "headerSeparator"
    case FooterSeparator = "footerSeparator"
    case GlobalHeaderBackground = "globalHeaderBackground"
}

// MARK: -

public class GridLayout: UICollectionViewLayout {
    
    public enum ZIndex: Int {
        
        case Background = -100
        case Item = 1
        case Supplement = 100
        case Decoration = 1000
        case ItemPinned = 9900
        case SupplementPinned = 10000
        case DecorationPinned = 11000
        
        init(category: UICollectionElementCategory, pinned: Bool = false) {
            switch (category, pinned) {
            case (.SupplementaryView, false):
                self = .Supplement
            case (.DecorationView, false):
                self = .Decoration
            case (.Cell, true):
                self = .ItemPinned
            case (.SupplementaryView, true):
                self = .SupplementPinned
            case (.DecorationView, true):
                self = .DecorationPinned
            default:
                self = .Item
            }
        }
        
    }
    
    private class func defaultPinnableBorderColor() -> UIColor {
        return UIColor(white: 0.8, alpha: 1)
    }
    
    typealias Attributes = GridLayoutAttributes
    typealias InvalidationContext = GridLayoutInvalidationContext
    
    private let layoutLogging = true
    
    private var layoutSize = CGSize.zeroSize
    private var oldLayoutSize = CGSize.zeroSize
    
    private var sections = [SectionInfo]()
    private var globalSection: SectionInfo?
    
    private var attributesCache = [ElementKey:Attributes]()
    private var attributesCacheOld = [ElementKey:Attributes]()
    
    private var nonPinnableGlobalAttributes = [Attributes]()
    private var pinnableAttributes = Multimap<Section, Attributes>()
    
    private var updateSectionDirections = [Section: SectionOperationDirection]()
    private var insertedIndexPaths = Set<NSIndexPath>()
    private var removedIndexPaths = Set<NSIndexPath>()
    private var insertedSections = NSMutableIndexSet()
    private var removedSections = NSMutableIndexSet()
    private var reloadedSections = NSMutableIndexSet()
    
    private var measuringElement: (ElementKey, CGRect)?
    
    private var globalSectionBackground: Attributes? {
        let key = ElementKey(decoration: DecorationKind.GlobalHeaderBackground.rawValue, NSIndexPath(0))
        return attributesCache[key]
    }
    
    private struct Flags {
        /// layout data becomes invalid if the data source changes
        var layoutDataIsValid = false
        /// layout metrics will only be valid if layout data is also valid
        var layoutMetricsAreValid = false
        /// contentOffset of collection view is valid
        var useCollectionViewContentOffset = false
        /// are we in the progress of laying out items
        var preparingLayout = false
    }
    private var flags = Flags()
    
    private var contentSizeAdjustment = CGSize.zeroSize
    private var contentOffsetAdjustment = CGPoint.zeroPoint
    
    private var hairline: CGFloat = 1
    private var lastPreparedCollectionView: ObjectIdentifier? = nil
    
    public func prepare(forCollectionView collectionView: UICollectionView?) {
        hairline = collectionView?.hairline ?? 1
    }
    
    // MARK: Logging
    
    private func log<T>(@autoclosure message: () -> T, functionName: StaticString = __FUNCTION__) {
        if !layoutLogging { return }
        println("\(functionName) \(message())")
    }
    
    private func trace(functionName: StaticString = __FUNCTION__) {
        if !layoutLogging { return }
        println("LAYOUT TRACE: \(functionName)")
    }

    // MARK: Init

    func commonInit() {
        register(typeForDecoration: ColorView.self, ofKind: DecorationKind.RowSeparator)
        register(typeForDecoration: ColorView.self, ofKind: DecorationKind.ColumnSeparator)
        register(typeForDecoration: ColorView.self, ofKind: DecorationKind.HeaderSeparator)
        register(typeForDecoration: ColorView.self, ofKind: DecorationKind.FooterSeparator)
        register(typeForDecoration: ColorView.self, ofKind: DecorationKind.GlobalHeaderBackground)
    }

    public override init() {
        super.init()
        commonInit()
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    // MARK: Public
    
    // TODO:
    // This probably needs to go away
    public func invalidateLayout(forItemAtIndexPath indexPath: NSIndexPath) {
        
        var section = sections[indexPath.section]
        section.remeasureItem(atIndex: indexPath.item) { (index, measuringRect) in
            self.measuringElement = (ElementKey(indexPath), measuringRect)
            let ret = self.collectionView?.cellForItemAtIndexPath(indexPath)?.preferredLayoutSize(fittingSize: measuringRect.size) ?? CGSize.zeroSize
            self.measuringElement = nil
            return ret
        }
        sections[indexPath.section] = section
        
        let context = InvalidationContext()
        context.invalidateLayoutMetrics = true
        invalidateLayoutWithContext(context)
    }
    
    public func invalidateLayoutForGlobalSection() {
        globalSection = nil
        
        let context = InvalidationContext()
        context.invalidateLayoutMetrics = true
        invalidateLayoutWithContext(context)
    }
    
    // MARK: Hacks
    
    private var layoutAttributesType: Attributes.Type {
        return self.dynamicType.layoutAttributesClass() as! Attributes.Type
    }
    
    private var invalidationContextType: InvalidationContext.Type {
        return self.dynamicType.layoutAttributesClass() as! InvalidationContext.Type
    }
    
    public weak var metricsProvider: MetricsProviderLegacy?
    
    // MARK: UICollectionViewLayout
    
    public override class func layoutAttributesClass() -> AnyClass {
        return Attributes.self
    }
    
    public override class func invalidationContextClass() -> AnyClass {
        return InvalidationContext.self
    }
    
    public override func invalidateLayoutWithContext(origContext: UICollectionViewLayoutInvalidationContext) {
        let context = origContext as! GridLayoutInvalidationContext
        
        flags.useCollectionViewContentOffset = context.invalidateLayoutOrigin
        
        if context.invalidateEverything {
            flags.layoutMetricsAreValid = false
            flags.layoutDataIsValid = false
        }
        
        if flags.layoutDataIsValid {
            let invalidateCounts = context.invalidateDataSourceCounts
            
            flags.layoutMetricsAreValid = !invalidateCounts && !context.invalidateLayoutMetrics
            if invalidateCounts {
                flags.layoutDataIsValid = false
            }
        }
        
        contentSizeAdjustment = CGSize.zeroSize
        contentOffsetAdjustment = CGPoint.zeroPoint
        
        log("layoutDataIsValid \(flags.layoutDataIsValid), layoutMetricsAreValid \(flags.layoutMetricsAreValid)")
        
        super.invalidateLayoutWithContext(context)
        
        switch (Constants.isiOS7, collectionView) {
        case (true, .Some(let cv)):
            let offset = context.contentOffsetAdjustment
            if offset != CGPoint.zeroPoint {
                cv.contentOffset += offset
            }
            
            let size = context.contentSizeAdjustment
            if size != CGSize.zeroSize {
                cv.contentSize += size
            }
        default: break
        }
    }
    
    public override func prepareLayout() {
        trace()
        log("bounds = \(collectionView?.bounds ?? CGRect.zeroRect)")
        
        contentSizeAdjustment = CGSize.zeroSize
        contentOffsetAdjustment = CGPoint.zeroPoint
        
        let cvPtr = collectionView.map { ObjectIdentifier($0) }
        if cvPtr != lastPreparedCollectionView {
            prepare(forCollectionView: collectionView)
            lastPreparedCollectionView = cvPtr
        }
        
        if collectionView?.window == nil {
            flags.layoutMetricsAreValid = false
            flags.layoutDataIsValid = false
        }
        
        let bounds = collectionView?.bounds ?? CGRect.zeroRect
        if !bounds.isEmpty {
            buildLayout()
        }
        
        super.prepareLayout()
    }
    
    public override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        trace()
        updateSpecialAttributes()
        let ret = attributesCache.values.filter {
            $0.frame.intersects(rect)
        }.array
        log("Requested layout attributes:\n\(layoutAttributesDescription(ret))")
        return ret
    }
    
    public override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        trace()
        
        let key = ElementKey(indexPath)
        if let existing = attributesCache[key] {
            log("Found attributes for \(indexPath.stringValue): \(existing.frame)")
            return existing
        }
        
        let (section, index) = key.components
        if let info = sectionInfo(forSection: section) {
            let columnIndex = info.metrics.numberOfColumns.map { key.indexPath.item % $0 } ?? 0
            let attribute = createItemAttributes(element: key, section: info.metrics, item: info[index], columnIndex: columnIndex)
            log("Synthesized attributes for \(indexPath.stringValue): \(attribute.frame) (preparing layout \(flags.preparingLayout))")
            if flags.preparingLayout {
                attribute.hidden = true
            } else {
                attributesCache[key] = attribute
            }
            return attribute
        }

        return nil
    }
    
    public override func layoutAttributesForSupplementaryViewOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        trace()
        
        let key = ElementKey(supplement: kind, indexPath)
        if let existing = attributesCache[key] {
            log("Found attributes for \(key): \(existing.frame)")
            return existing
        }
        
        let (section, index) = key.components
        if let info = sectionInfo(forSection: section) {
            let attribute = createSupplementAttributes(element: key, section: info, item: info[kind, index])
            if flags.preparingLayout {
                attribute.hidden = true
            } else {
                attributesCache[key] = attribute
            }
            return attribute
        }
        
        return nil
    }
    
    public override func layoutAttributesForDecorationViewOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        trace()
        
        let key = ElementKey(decoration: kind, indexPath)
        if let existing = attributesCache[key] {
            log("Found attributes for \(kind)@\(indexPath.stringValue): \(existing.frame)")
            return existing
        }
        
        let (section, _) = key.components
        switch (DecorationKind(rawValue: kind), sectionInfo(forSection: section)) {
        case (.Some(let decoration), .Some(let info)):
            let attribute = createDecorationAttributes(element: key, decoration: decoration, section: info)
            if flags.preparingLayout {
                attribute.hidden = true
            } else {
                attributesCache[key] = attribute
            }
            return attribute
        default:
            return nil
        }
    }
    
    public override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return true
    }
    
    public override func invalidationContextForBoundsChange(newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let oldBounds = collectionView?.bounds ?? CGRect.zeroRect
        let context = super.invalidationContextForBoundsChange(newBounds) as! InvalidationContext
        
        context.invalidateLayoutOrigin = newBounds.origin == oldBounds.origin
        context.invalidateLayoutMetrics = newBounds.width != oldBounds.width
        
        return context
    }
    
    public override func targetContentOffsetForProposedContentOffset(proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
    
    public override func targetContentOffsetForProposedContentOffset(proposedContentOffset: CGPoint) -> CGPoint {
        let bounds = collectionView?.bounds ?? CGRect.zeroRect
        let insets = collectionView?.contentInset ?? UIEdgeInsetsZero
        
        var targetContentOffset = proposedContentOffset
        targetContentOffset.y += insets.top
        
        let availableHeight = UIEdgeInsetsInsetRect(bounds, insets).height
        targetContentOffset.y = min(targetContentOffset.y, max(0, layoutSize.height - availableHeight))
        
        let firstInsertedIndex = insertedSections.firstIndex
        if firstInsertedIndex != NSNotFound && (updateSectionDirections[.Index(firstInsertedIndex)] ?? .Default) != .Default {
            let globalNonPinnable = height(ofAttributes: nonPinnableGlobalAttributes)
            let globalPinnable = globalSection.map { $0.frame.height - globalNonPinnable } ?? -globalNonPinnable
            
            let minY = sections[firstInsertedIndex].frame.minY
            if targetContentOffset.y + globalPinnable > minY {
                targetContentOffset.y = max(globalNonPinnable, minY - globalPinnable)
            }
        }
        
        targetContentOffset.y -= insets.top
        
        return targetContentOffset
    }
    
    public override func collectionViewContentSize() -> CGSize {
        trace()
        return flags.preparingLayout ? oldLayoutSize : layoutSize
    }
    
    public override func prepareForCollectionViewUpdates(updateItems: [AnyObject]!) {
        trace()

        for updateItem in updateItems as! [UICollectionViewUpdateItem] {
            switch (updateItem.updateAction, updateItem.indexPathBeforeUpdate, updateItem.indexPathAfterUpdate) {
            case (.Insert, _, .Some(let indexPath)) where indexPath.item == NSNotFound:
                insertedSections.addIndex(indexPath.section)
            case (.Insert, _, .Some(let indexPath)):
                insertedIndexPaths.insert(indexPath)
            case (.Delete, .Some(let indexPath), _) where indexPath.item == NSNotFound:
                removedSections.addIndex(indexPath.section)
            case (.Delete, .Some(let indexPath), _):
                removedIndexPaths.insert(indexPath)
            case (.Reload, _, .Some(let indexPath)) where indexPath.item == NSNotFound:
                reloadedSections.addIndex(indexPath.section)
            default: break
            }
        }
        
        let contentOffset = collectionView?.contentOffset ?? CGPoint.zeroPoint
        let newContentOffset = targetContentOffsetForProposedContentOffset(contentOffset)
        contentOffsetAdjustment = newContentOffset - contentOffset
        
        super.prepareForCollectionViewUpdates(updateItems)
    }
    
    public override func finalizeCollectionViewUpdates() {
        trace()
        insertedIndexPaths.removeAll()
        removedIndexPaths.removeAll()
        insertedSections.removeAllIndexes()
        removedSections.removeAllIndexes()
        reloadedSections.removeAllIndexes()
        updateSectionDirections.removeAll()
        super.finalizeCollectionViewUpdates()
    }
    
    public override func indexPathsToDeleteForDecorationViewOfKind(kind: String) -> [AnyObject] {
        return attributesCacheOld.keys.filter { key in
            switch key {
            case .Decoration(_, let dKind) where dKind == kind:
                return self.attributesCache[key] == nil
            default:
                return false
            }
        }.map { $0.indexPath }.array
    }
    
    public override func initialLayoutAttributesForAppearingDecorationElementOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("initial decoration:\(kind) indexPath:\(indexPath.stringValue)")
        
        let key = ElementKey(decoration: kind, indexPath)
        let (section, _) = key.components
        
        if var result = attributesCache[key]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureInitial(attributes: &result, inFromDirection: direction, shouldFadeIn:
                insertedSections ~= section || (reloadedSections ~= section && attributesCacheOld[key] == nil))
            
            return result
        }
        
        return nil
    }
    
    public override func finalLayoutAttributesForDisappearingDecorationElementOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("final decoration:\(kind) indexPath:\(indexPath.stringValue)")
        
        let key = ElementKey(decoration: kind, indexPath)
        let (section, _) = key.components
        
        if var result = attributesCacheOld[key]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureFinal(attributes: &result, outToDirection: direction, shouldFadeOut:
                removedSections ~= section || (reloadedSections ~= section && attributesCache[key] == nil))
            
            return result
        }
        
        return nil
    }
    
    public override func initialLayoutAttributesForAppearingSupplementaryElementOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("initial supplement:\(kind) indexPath:\(indexPath.stringValue)")
        
        let key = ElementKey(supplement: kind, indexPath)
        let (section, _) = key.components
        
        if var result = attributesCache[key]?.copy() as? Attributes {
            if kind == SupplementKind.Placeholder.rawValue {
                configureInitial(attributes: &result, inFromDirection: .Default)
            } else {
                let direction = updateSectionDirections[section] ?? .Default
                let inserted = insertedSections ~= section
                let offsets = direction != .Default && inserted
                
                configureInitial(attributes: &result, inFromDirection: direction, makeFrameAdjustments: offsets, shouldFadeIn:
                    inserted || (reloadedSections ~= section && attributesCacheOld[key] == nil))
            }
            
            return result
        }
        
        return nil
    }
    
    public override func finalLayoutAttributesForDisappearingSupplementaryElementOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("final supplement:\(kind) indexPath:\(indexPath.stringValue)")
        
        let key = ElementKey(supplement: kind, indexPath)
        let (section, _) = key.components
        
        if var result = attributesCacheOld[key]?.copy() as? Attributes {
            if kind == SupplementKind.Placeholder.rawValue {
                configureFinal(attributes: &result, outToDirection: .Default)
            } else {
                let direction = updateSectionDirections[section] ?? .Default
                configureFinal(attributes: &result, outToDirection: direction, shouldFadeOut:
                    removedSections ~= section || reloadedSections ~= section)
            }
            
            return result
        }
        
        return nil
    }
    
    public override func initialLayoutAttributesForAppearingItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("initial indexPath:\(indexPath.stringValue)")
        
        let key = ElementKey(indexPath)
        let (section, _) = key.components
        
        if var result = attributesCache[key]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureInitial(attributes: &result, inFromDirection: direction, shouldFadeIn:
                insertedSections ~= section || insertedIndexPaths.contains(indexPath) || (reloadedSections ~= section && attributesCacheOld[key] == nil))
            
            return result
        }
        
        return nil
    }
    
    public override func finalLayoutAttributesForDisappearingItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("final indexPath:\(indexPath.stringValue)")
        
        let key = ElementKey(indexPath)
        let (section, _) = key.components
        
        if var result = attributesCacheOld[key]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureFinal(attributes: &result, outToDirection: direction, shouldFadeOut:
                removedIndexPaths.contains(indexPath) || removedSections ~= section || (reloadedSections ~= section && attributesCache[key] == nil))
            
            return result
        }
        
        return nil
    }
    
    // MARK: Internal
    
    private func resetLayoutInfo() {
        sections.removeAll(keepCapacity: true)
        globalSection = nil
        
        attributesCacheOld.removeAll()
        swap(&attributesCache, &attributesCacheOld)
        
        pinnableAttributes.removeAll()
        nonPinnableGlobalAttributes.removeAll()
    }
    
    private func mapMetrics<T>(#provider: MetricsProviderLegacy?, transform: (Section, SectionMetrics, [SupplementaryMetrics]) -> T) -> (global: T?, sections: [T]) {
        let global = provider.map { provider -> T in
            let globalMetrics = provider.snapshotMetrics(section: .Global)
            let globalSnapshots = provider.snapshotSupplements(section: .Global)
            return transform(.Global, globalMetrics, globalSnapshots)
        }
        
        let numberOfSections = collectionView?.numberOfSections() ?? 0
        let sections = map(0..<numberOfSections) { idx -> T in
            let section = Section.Index(idx)
            let sectionMetrics = provider?.snapshotMetrics(section: section) ?? SectionMetrics.defaultMetrics
            let sectionSupplements = provider?.snapshotSupplements(section: section) ?? []
            return transform(section, sectionMetrics, sectionSupplements)
        }
        
        return (global, sections)
    }
    
    private func createLayoutInfoFromDataSource() {
        trace()
        
        resetLayoutInfo()
        
        let bounds = collectionView?.bounds
        let insets = collectionView?.contentInset ?? UIEdgeInsetsZero
        let height = bounds.map { $0.height - insets.top - insets.bottom } ?? 0
        let numberOfSections = collectionView?.numberOfSections() ?? 0
        
        func fromMetrics(color: UIColor?) -> UIColor? {
            return color == UIColor.clearColor() ? nil : color
        }
        
        (globalSection, sections) = mapMetrics(provider: metricsProvider) { (section, var metrics, supplements) -> SectionInfo in
            metrics.backgroundColor = fromMetrics(metrics.backgroundColor)
            metrics.selectedBackgroundColor = fromMetrics(metrics.selectedBackgroundColor)
            metrics.tintColor = fromMetrics(metrics.tintColor)
            metrics.selectedTintColor = fromMetrics(metrics.selectedTintColor)
            metrics.separatorColor = fromMetrics(metrics.separatorColor)
            metrics.numberOfColumns = min(metrics.numberOfColumns ?? 0, 1)
            switch (section, metrics.padding) {
            case (.Global, .Some(let padding)):
                metrics.padding = UIEdgeInsetsMake(0, padding.left, padding.bottom, padding.right)
            default: break
            }
            
            var info = SectionInfo(metrics: metrics)
            
            for (var suplMetric) in supplements {
                if suplMetric.kind == SupplementKind.Header.rawValue {
                    suplMetric.backgroundColor = fromMetrics(suplMetric.backgroundColor) ?? metrics.backgroundColor
                    suplMetric.selectedBackgroundColor = fromMetrics(suplMetric.selectedBackgroundColor) ?? metrics.selectedBackgroundColor
                    suplMetric.tintColor = fromMetrics(suplMetric.tintColor) ?? metrics.tintColor
                    suplMetric.selectedTintColor = fromMetrics(suplMetric.selectedTintColor) ?? metrics.selectedTintColor
                } else {
                    suplMetric.isVisibleWhileShowingPlaceholder = false
                    suplMetric.shouldPin = false
                }
                
                info.addSupplementalItem(suplMetric)
            }
            
            // A section can either have a placeholder or items. Arbitrarily deciding the placeholder takes precedence.
            switch (section, metrics.hasPlaceholder) {
            case (_, true):
                info.addPlaceholder()
            case (.Index(let idx), _):
                info.addItems(self.collectionView?.numberOfItemsInSection(idx) ?? 0)
            default: break
            }
            
            return info
        }
    }
    
    private func buildLayout() {
        if flags.layoutMetricsAreValid || flags.preparingLayout { return }
        flags.preparingLayout = true
        
        trace()
        
        if !flags.layoutDataIsValid {
            createLayoutInfoFromDataSource()
            flags.layoutDataIsValid = true
        }
        
        oldLayoutSize = layoutSize
        layoutSize = CGSize.zeroSize
        
        let contentInset = collectionView?.contentInset ?? UIEdgeInsetsZero
        let contentOffsetY = collectionView.map { $0.contentOffset.y + contentInset.top } ?? 0
        
        let viewportSize = collectionView?.bounds.rectByInsetting(insets: contentInset).size ?? CGSize.zeroSize
        var layoutRect = CGRect(origin: CGPoint.zeroPoint, size: viewportSize)
        var start = layoutRect.origin
        
        var shouldInvalidate = false
        let measureSupplement = { (kind: String, indexPath: NSIndexPath, measuringFrame: CGRect) -> CGSize in
            shouldInvalidate = true
            self.measuringElement = (ElementKey(supplement: kind, indexPath), measuringFrame)
            let ret = self.metricsProvider?.sizeFittingSize(measuringFrame.size, supplementaryElementOfKind: kind, indexPath: indexPath, collectionView: self.collectionView!) ?? measuringFrame.size
            self.measuringElement = nil
            return ret
        }
        
        // build global section
        globalSection?.layout(rect: layoutRect, nextStart: &start, measureSupplement: {
            measureSupplement($0, NSIndexPath($1), $2)
        })
        
        if let section = globalSection {
            addLayoutAttributes(forSection: .Global, withInfo: section)
        }
        
        // build all sections
        sections = sections.mapWithIndex { (sectionIndex, var section) -> SectionInfo in
            layoutRect.size.height = max(0, layoutRect.height - start.y + layoutRect.minY)
            layoutRect.origin = start
            
            section.layout(rect: layoutRect, nextStart: &start, measureSupplement: {
                measureSupplement($0, NSIndexPath(sectionIndex, $1), $2)
            }, measureItem: { (index, measuringRect) in
                let indexPath = NSIndexPath(sectionIndex, index)
                self.measuringElement = (ElementKey(indexPath), measuringRect)
                let ret = self.metricsProvider?.sizeFittingSize(measuringRect.size, itemAtIndexPath: indexPath, collectionView: self.collectionView!) ?? measuringRect.size
                self.measuringElement = nil
                return ret
            })
            
            self.addLayoutAttributes(forSection: .Index(sectionIndex), withInfo: section)
            
            return section
        }
        
        // Calculate layout size
        let globalNonPinningHeight = height(ofAttributes: self.nonPinnableGlobalAttributes)
        let layoutHeight = { _ -> CGFloat in
            if contentOffsetY >= globalNonPinningHeight && start.y - globalNonPinningHeight < viewportSize.height {
                return viewportSize.height + globalNonPinningHeight
            }
            return start.y
        }()
        
        layoutSize = CGSize(width: layoutRect.width, height: layoutHeight)
        
        // Update pinning
        updateSpecialAttributes()
        
        // Done!
        flags.layoutMetricsAreValid = true
        flags.preparingLayout = false
        
        log("prepared layout attributes:\n\(layoutAttributesDescription(attributesCache.values))")
        
        // But if the headers changed, we need to invalidate…
        if (shouldInvalidate) {
            invalidateLayout()
        }
    }
    
    private func addLayoutAttributes(forSection section: Section, withInfo info: SectionInfo) {
        let isGlobal = section == .Global
        let indexPath = { (idx: Int) -> NSIndexPath in
            switch section {
            case .Global:
                return NSIndexPath(idx)
            case .Index(let section):
                return NSIndexPath(section, idx)
            }
        }
        
        // Add the background decoration attribute
        if isGlobal && globalSectionBackground == nil {
            let key = ElementKey(decoration: DecorationKind.GlobalHeaderBackground.rawValue, indexPath(0))
            attributesCache[key] = createDecorationAttributes(element: key, decoration: .GlobalHeaderBackground, section: info)
        }
        
        // Lay out headers
        for (kind, idx, item) in info[.Header] {
            if info.numberOfItems == 0 && !item.metrics.isVisibleWhileShowingPlaceholder { continue }
            let ip = indexPath(idx)
            
            if let attribute = addSupplementAttributes(kind: kind, indexPath: ip, section: info, item: item) {
                appendPinned(attribute, section: section, shouldPin: item.metrics.shouldPin)
                
                // Separators after global headers, before regular headers
                if let separator = addSeparator(kind: .HeaderSeparator, indexPath: ip, section: info, force: isGlobal) {
                    appendPinned(separator, section: section, shouldPin: item.metrics.shouldPin)
                }
            }
        }
        
        // Separator after non-global headers
        let numberOfHeaders = info.count(supplements: .Header) ?? 0
        let numberOfItems = info.numberOfItems
        addSeparator(numberOfHeaders != 0 || numberOfItems != 0, kind: .HeaderSeparator, indexPath: indexPath(numberOfHeaders), section: info)
        
        // Lay out rows
        let numberOfColumns = info.metrics.numberOfColumns ?? 1
        for (rowIndex, row) in enumerate(info.rows) {
            if row.items.isEmpty { continue }
            
            for (columnIndex, item) in enumerate(row.items) {
                let ip = indexPath(rowIndex * numberOfColumns + columnIndex)
                let key = ElementKey(ip)
                
                attributesCache[key] = createItemAttributes(element: key, section: info.metrics, item: item, columnIndex: columnIndex)

                addSeparator(columnIndex > 0, kind: .ColumnSeparator, indexPath: ip, section: info)
            }
            
            // If there's a separator, add it above the current row…
            addSeparator(rowIndex > 0, kind: .RowSeparator, indexPath: indexPath(rowIndex * numberOfColumns), section: info)
        }
        
        // Lay out other supplements
        for (kind, idx, item) in info[.Footer] {
            let ip = indexPath(idx)
            if let attribute = addSupplementAttributes(kind: kind, indexPath: ip, section: info, item: item) {
                addSeparator(kind: .FooterSeparator, indexPath: ip, section: info)
            }
        }
        
        for (kind, idx, item) in info[.AllOther] {
            addSupplementAttributes(kind: kind, indexPath: indexPath(idx), section: info, item: item)
        }
        
        // Add the section separator below this section provided it's not the last section (or if the section explicitly says to)
        addSeparator(!isGlobal && numberOfItems != 0, kind: .FooterSeparator, indexPath: indexPath(numberOfItems), section: info)
    }
    
    // MARK: Pinning
    
    private func resetPinnable(#attributes: Attributes) {
        attributes.pinning.isPinned = false
        if attributes.pinning.isHiddenNormally {
            attributes.hidden = true
        }

        if let unpinned = attributes.pinning.unpinnedY {
            attributes.frame.origin.y = unpinned
        }
    }

    private func finalizePinning(#attributes: Attributes, offset: Int, pinned: Bool = false) {
        let zIndex = ZIndex(category: attributes.representedElementCategory, pinned: pinned)
        attributes.zIndex = zIndex.rawValue - offset - 1
        
        let isPinned = attributes.frame.minY !~== attributes.pinning.unpinnedY
        attributes.pinning.isPinned = isPinned
        if attributes.hidden {
            attributes.hidden = !isPinned
        }
    }
    
    // pin the attributes starting at minY as long a they don't cross maxY and return the new minY
    private func applyTopPinning(#attributes: Attributes, inout pinnableY: CGFloat) {
        if attributes.frame.minY < pinnableY {
            attributes.frame.origin.y = pinnableY
            pinnableY = attributes.frame.maxY
        }
    }

    private func applyBottomPinning(#attributes: Attributes, inout nonPinnableY: CGFloat) {
        if attributes.frame.maxY < nonPinnableY {
            attributes.frame.origin.y = nonPinnableY - attributes.frame.height
            nonPinnableY = attributes.frame.minY
        }
    }

    private func updateSpecialAttributes() {
        let countSections = collectionView?.numberOfSections()
        if countSections < 1 { return }
        
        let normalContentOffset = collectionView?.contentOffset ?? CGPoint.zeroPoint
        let contentOffset = flags.useCollectionViewContentOffset ? normalContentOffset : targetContentOffsetForProposedContentOffset(normalContentOffset)
        let minY = collectionView?.contentInset.top ?? 0
        
        // Adjust a global background
        if let background = globalSectionBackground {
            background.frame.origin.y = minY + contentOffset.y

            let lastGlobalRect = pinnableAttributes[.Global].last?.frame ?? CGRect.zeroRect
            let lastRegularRect = nonPinnableGlobalAttributes.last?.frame ?? CGRect.zeroRect
            background.frame.size.height = fmax(lastGlobalRect.maxY, lastRegularRect.maxY) - background.frame.origin.y
        }

        /*var pinnableY = minY + contentOffset.y
        var nonPinnableY = pinnableY
        
        // Pin the headers as appropriate
        for (idx, info) in enumerate(pinnableAttributes[.Global]) {
            resetPinnable(attributes: info)
            applyTopPinning(attributes: info, pinnableY: &pinnableY)
            finalizePinning(attributes: info, offset: idx, pinned: true)
        }
        
        nonPinnableGlobalAttributes = nonPinnableGlobalAttributes.mapWithIndexReversed {
            self.resetPinnable(attributes: $1)
            self.applyBottomPinning(attributes: $1, nonPinnableY: &nonPinnableY)
            self.finalizePinning(attributes: $1, offset: $0)
            return $1
        }
        
        // Adjust a global background
        if let background = globalSectionBackground {
            background.frame.origin.y = min(nonPinnableY, minY)
            
            let lastGlobalRect = pinnableAttributes[.Global].last?.frame ?? CGRect.zeroRect
            let lastRegularRect = nonPinnableGlobalAttributes.last?.frame ?? CGRect.zeroRect
            background.frame.size.height = fmax(lastGlobalRect.maxY, lastRegularRect.maxY) - background.frame.origin.y
        }
        
        // Pin attributes in a pinned section
        // Reset pinnable attributes for all others
        var foundSection = false
        for (section, values) in pinnableAttributes.groups() {
            switch section {
            case .Index(let idx):
                for attr in values {
                    resetPinnable(attributes: attr)
                }
                
                let frame = sections[idx].frame
                if !foundSection && frame.minY <= pinnableY && pinnableY <= frame.maxY {
                    foundSection = true
                    
                    for (idx, attr) in enumerate(values) {
                        applyTopPinning(attributes: attr, pinnableY: &pinnableY)
                        finalizePinning(attributes: attr, offset: idx, pinned: true)
                    }
                }
            case .Global: break
            }
        }*/
    }
    
    // MARK: Helpers
    
    private func appendPinned(attribute: Attributes, section: Section, shouldPin: Bool = false) {
        if shouldPin {
            pinnableAttributes.append(attribute, forKey: section)
        } else if section == .Global {
            nonPinnableGlobalAttributes.append(attribute)
        }
    }
    
    private func createItemAttributes(element key: ElementKey, section: SectionMetrics, item: ItemInfo?, columnIndex: Int) -> Attributes {
        let attribute = layoutAttributesType(forElement: key)

        attribute.frame = { _ -> CGRect in
            switch (self.measuringElement, item) {
            case (.Some(let (mKey, rect)), _) where mKey == key:
                return rect
            case (_, .Some(let item)):
                return item.frame
            default:
                return CGRect.zeroRect
            }
        }()
        attribute.zIndex = ZIndex.Item.rawValue
        attribute.backgroundColor = section.backgroundColor
        attribute.selectedBackgroundColor = section.selectedBackgroundColor
        attribute.tintColor = section.tintColor
        attribute.selectedTintColor = section.selectedTintColor
        attribute.padding = item?.padding ?? UIEdgeInsetsZero
        attribute.columnIndex = columnIndex
        

        return attribute
    }
    
    private func createSupplementAttributes(element key: ElementKey, section: SectionInfo, item: SupplementInfo?) -> Attributes {
        let attribute = layoutAttributesType(forElement: key)
        let frame = { _ -> CGRect in
            switch (self.measuringElement, item) {
            case (.Some(let mKey, let rect), _) where mKey == key:
                return rect
            case (_, .Some(let item)):
                return item.frame
            default:
                return CGRect.zeroRect
            }
        }()
        let hidden = item?.metrics.isHidden ?? false
        
        attribute.frame = frame
        attribute.hidden = hidden || frame.isEmpty
        attribute.zIndex = ZIndex.Supplement.rawValue
        attribute.backgroundColor = item?.metrics.backgroundColor ?? section.metrics.backgroundColor
        attribute.selectedBackgroundColor = item?.metrics.selectedBackgroundColor ?? section.metrics.selectedBackgroundColor
        attribute.tintColor = item?.metrics.tintColor ?? section.metrics.tintColor
        attribute.selectedTintColor = item?.metrics.selectedTintColor ?? section.metrics.selectedTintColor
        attribute.padding = item?.metrics.padding ?? UIEdgeInsetsZero
        attribute.pinning = (false, false, frame.minY)
        
        return attribute
    }
    
    private func createDecorationAttributes(element key: ElementKey, decoration: DecorationKind, section: SectionInfo /*, item: SupplementInfo?*/) -> Attributes {
        var attribute = layoutAttributesType(forElement: key)
        
        switch decoration {
        case .GlobalHeaderBackground:
            let frame = section.frame ?? CGRect.zeroRect
            let color = section.metrics.backgroundColor
            
            attribute.frame = frame
            attribute.zIndex = ZIndex.Background.rawValue
            attribute.hidden = color == nil
            attribute.backgroundColor = color
            attribute.pinning = (false, false, frame.minY)
        case .RowSeparator:
            let itemKey = key.correspondingItem
            let item = attributesCache[itemKey]
            let rect = { () -> CGRect in
                switch (item?.frame, section.metrics.separatorInsets) {
                case (.Some(let frame), .Some(let insets)):
                    return frame.rectByInsetting(insets: insets.horizontalInsets)
                case (.Some(let frame), _):
                    return frame
                default:
                    return CGRect.zeroRect
                }
            }()
            configureSeparator(attributes: &attribute, bit: .Rows, toRect: rect, edge: .MinYEdge, section: section)
        case .ColumnSeparator:
            let itemKey = key.correspondingItem
            let item = attributesCache[itemKey]
            let rect = { () -> CGRect in
                switch (item?.frame, section.metrics.separatorInsets) {
                case (.Some(let frame), .Some(let insets)):
                    return frame.rectByInsetting(insets: insets.verticalInsets)
                case (.Some(let frame), _):
                    return frame
                default:
                    return CGRect.zeroRect
                }
            }()
            configureSeparator(attributes: &attribute, bit: .Columns, toRect: rect, edge: .MinXEdge, section: section)
        case .HeaderSeparator:
            let headerKey = key.correspondingSupplement(SupplementKind.Header.rawValue)
            let header = attributesCache[headerKey]
            let (bit, rect, edge) = { () -> (SeparatorOptions, CGRect, CGRectEdge) in
                let numberOfHeaders = section.count(supplements: .Header) ?? 0
                let numberOfItems = section.numberOfItems
                switch (header, numberOfHeaders, numberOfItems) {
                case (.Some(let item), _, _):
                    return (.Supplements, item.frame, .MaxYEdge)
                case (_, let headers, 0) where headers != 0:
                    return (.AfterSections, section.contentRect, .MaxYEdge)
                default:
                    return (.BeforeSections, section.contentRect, .MinYEdge)
                }
            }()

            configureSeparator(attributes: &attribute, bit: bit, toRect: rect, edge: edge, section: section)
        case .FooterSeparator:
            let footerKey = key.correspondingSupplement(SupplementKind.Footer.rawValue)
            let footer = attributesCache[footerKey]
            let (bit, rect, edge) = { () -> (SeparatorOptions, CGRect, CGRectEdge) in
                let numberOfFooters = section.count(supplements: .Footer) ?? 0
                let numberOfItems = section.numberOfItems
                switch (footer, numberOfFooters, numberOfItems) {
                case (.Some(let item), _, _):
                    return (.Supplements, item.frame, .MaxYEdge)
                default:
                    return (.AfterSections, section.contentRect, .MaxYEdge)
                }
            }()

            configureSeparator(attributes: &attribute, bit: bit, toRect: rect, edge: edge, section: section)
        }
        
        return attribute
    }
    
    private func configureSeparator(inout #attributes: Attributes, bit: SeparatorOptions, toRect rect: CGRect, edge: CGRectEdge, section: SectionInfo) {
        let frame = rect.separatorRect(edge: edge, thickness: hairline)
        let skipped = rect.isEmpty || !(section.metrics.separators ~= bit) || section.metrics.separatorColor == nil
        let color = section.metrics.separatorColor ?? self.dynamicType.defaultPinnableBorderColor()
        
        attributes.frame = frame
        attributes.zIndex = ZIndex.Decoration.rawValue
        attributes.hidden = skipped
        attributes.backgroundColor = color
        attributes.pinning = (false, skipped, frame.minY)
    }
    
    private func addSeparator(@autoclosure _ predicate: () -> Bool = true, kind: DecorationKind, @autoclosure indexPath getIndexPath: () -> NSIndexPath, section: SectionInfo, force: Bool = false) -> Attributes? {
        if !predicate() { return nil }
        
        let ip = getIndexPath()
        let key = ElementKey(decoration: kind.rawValue, ip)
        let attribute = createDecorationAttributes(element: key, decoration: kind, section: section)
        
        if attribute.hidden && !force { return nil }
        
        attributesCache[key] = attribute
        return attribute
    }
    
    private func addSupplementAttributes(#kind: String, indexPath: NSIndexPath, section: SectionInfo, item: SupplementInfo) -> Attributes? {
        let key = ElementKey(supplement: kind, indexPath)
        let attribute = createSupplementAttributes(element: key, section: section, item: item)
        attributesCache[key] = attribute
        return attribute
    }
    
    private func configureInitial(inout #attributes: Attributes, inFromDirection direction: SectionOperationDirection = .Default, makeFrameAdjustments: Bool = true, @autoclosure shouldFadeIn shouldFade: () -> Bool = true) {
        var endFrame = attributes.frame
        var endAlpha = attributes.alpha
        let bounds = collectionView!.bounds
        
        switch direction {
        case .Default:
            if shouldFade() { endAlpha = 0 }
        case .Left:
            endFrame.origin.x -= bounds.width
        case .Right:
            endFrame.origin.x += bounds.width
        }
        
        if makeFrameAdjustments {
            endFrame.offset(dx: contentOffsetAdjustment.x, dy: contentOffsetAdjustment.y)
        }

        attributes.alpha = endAlpha
        attributes.frame = endFrame
    }
    
    private func configureFinal(inout #attributes: Attributes, outToDirection direction: SectionOperationDirection = .Default, @autoclosure shouldFadeOut shouldFade: () -> Bool = true) {
        var endFrame = attributes.frame
        var endAlpha = attributes.alpha
        let bounds = collectionView!.bounds
        
        switch direction {
        case .Default:
            if shouldFade() { endAlpha = 0 }
        case .Left:
            endFrame.origin.x += bounds.width
            endAlpha = 0
        case .Right:
            endFrame.origin.x -= bounds.width
            endAlpha = 0
        }
        
        if attributes.pinning.isPinned {
            endFrame.origin.x += contentOffsetAdjustment.x
            endFrame.origin.y = max(attributes.pinning.unpinnedY ?? CGFloat.min, endFrame.minY + contentOffsetAdjustment.y)
        } else {
            endFrame.offset(dx: contentOffsetAdjustment.x, dy: contentOffsetAdjustment.y)
        }
        
        attributes.alpha = endAlpha
        attributes.frame = endFrame
    }
    
    private func sectionInfo(forSection section: Section) -> SectionInfo? {
        switch section {
        case .Global:
            return globalSection
        case .Index(let section):
            return sections[section]
        }
    }
    
}

extension GridLayout: DebugPrintable {
    
    private func layoutAttributesDescription<S: SequenceType where S.Generator.Element == Attributes>(attributes: S) -> String {
        return join("\n", lazy(attributes).map { attr in
            let typeStr = { () -> String in
                switch attr.representedElementCategory {
                case .Cell: return "Cell"
                case .DecorationView: return "Decoration \(attr.representedElementKind)"
                case .SupplementaryView: return "Supplement \(attr.representedElementKind)"
                }
            }()
            
            var ret = "  \(typeStr) indexPath=\(attr.indexPath.stringValue) frame=\(attr.frame)"
            if attr.hidden {
                ret += " hidden=true"
            }
            return ret
        })
    }
    
    public override var debugDescription: String {
        var ret = description
        
        if let section = globalSection {
            let desc = section.debugDescription
            ret += "    global = @[\n        \(desc)\n    ]"
        }
        
        if !sections.isEmpty {
            let desc = join(", ", sections.map { $0.debugDescription })
            ret += "\n    sections = @[\n        \(desc)\n    ]"
        }
        
        return ret
    }
    
}

extension GridLayout: DataSourcePresenter {
    
    public func dataSourceWillPerform(dataSource: DataSource, sectionAction: SectionAction) {
        
        func setSectionDirections(forIndexes indexes: NSIndexSet, direction: SectionOperationDirection) {
            for sectionIndex in indexes {
                self.updateSectionDirections[.Index(sectionIndex)] = direction
            }
        }
        
        switch sectionAction {
        case .Insert(let indexes, let direction):
            setSectionDirections(forIndexes: indexes, direction)
        case .Remove(let indexes, let direction):
            setSectionDirections(forIndexes: indexes, direction)
        case .Move(let section, let newSection, let direction):
            updateSectionDirections[.Index(section)] = direction
            updateSectionDirections[.Index(newSection)] = direction
        case .ReloadGlobal:
            invalidateLayoutForGlobalSection()
        default:
            break
        }
    }
    
}
