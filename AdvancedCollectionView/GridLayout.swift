//
//  GridLayout.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit


public protocol CollectionViewDataSourceGridLayout: UICollectionViewDataSource {
    
    /// Measure variable height cells. The goal here is to do the minimal necessary configuration to get the correct size information.
    func sizeFittingSize(size: CGSize, itemAtIndexPath indexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize
    
    /// Measure variable height supplements. The goal here is to do the minimal necessary configuration to get the correct size information.
    func sizeFittingSize(size: CGSize, supplementaryElementOfKind kind: String, indexPath: NSIndexPath, collectionView: UICollectionView) -> CGSize
    
    /// Compute a flattened snapshot of the layout metrics associated with this and any child data sources.
    func snapshotMetrics() -> [Section : SectionMetrics]
    
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
        case Item = 1
        case Supplement = 100
        case Decoration = 1000
        case OverlapPinned = 9900
        case SupplementPinned = 10000
    }
    
    typealias Attributes = GridLayoutAttributes
    typealias InvalidationContext = GridLayoutInvalidationContext
    
    private let layoutLogging = true
    
    private var layoutSize = CGSize.zeroSize
    private var oldLayoutSize = CGSize.zeroSize
    
    private var layoutAttributes = [Attributes]()
    private var sections = [SectionInfo]()
    private var globalSection: SectionInfo?
    
    private var globalSectionBackground: Attributes?
    private var nonPinnableGlobalAttributes = [Attributes]()
    private var pinnableAttributes = Multimap<Section, Attributes>()
    
    private var supplementaryAttributesCache = [GridCacheKey:Attributes]()
    private var supplementaryAttributesCacheOld = [GridCacheKey:Attributes]()
    private var decorationAttributesCache = [GridCacheKey:Attributes]()
    private var decorationAttributesCacheOld = [GridCacheKey:Attributes]()
    private var itemAttributesCache = [NSIndexPath:Attributes]()
    private var itemAttributesCacheOld = [NSIndexPath:Attributes]()
    
    private var updateSectionDirections = [Section: SectionOperationDirection]()
    private var insertedIndexPaths = Set<NSIndexPath>()
    private var removedIndexPaths = Set<NSIndexPath>()
    private var insertedSections = NSMutableIndexSet()
    private var removedSections = NSMutableIndexSet()
    private var reloadedSections = NSMutableIndexSet()
    
    private var measuringItem: (NSIndexPath, CGRect)?
    private var measuringSupplement: (String, NSIndexPath, CGRect)?
    
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
    private var lastPreparedCollectionView: UnsafePointer<Void> = nil
    
    public func prepare(forCollectionView collectionView: UICollectionView?) {
        hairline = collectionView?.hairline ?? 1
    }
    
    // MARK: Logging
    
    private func log<T>(message: @autoclosure () -> T, functionName: StaticString = __FUNCTION__) {
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
            self.measuringItem = (indexPath, measuringRect)
            return self.collectionView?.cellForItemAtIndexPath(indexPath)?.preferredLayoutSize(fittingSize: measuringRect.size) ?? CGSize.zeroSize
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
        return self.dynamicType.layoutAttributesClass() as Attributes.Type
    }
    
    private var invalidationContextType: InvalidationContext.Type {
        return self.dynamicType.layoutAttributesClass() as InvalidationContext.Type
    }
    
    private var dataSource: CollectionViewDataSourceGridLayout? {
        // :-(
        if let collectionView = collectionView {
            return collectionView.dataSource as? DataSource
        }
        return nil
    }
    
    // MARK: UICollectionViewLayout
    
    public override class func layoutAttributesClass() -> AnyClass {
        return Attributes.self
    }
    
    public override class func invalidationContextClass() -> AnyClass {
        return InvalidationContext.self
    }
    
    public override func invalidateLayoutWithContext(origContext: UICollectionViewLayoutInvalidationContext) {
        let context = origContext as GridLayoutInvalidationContext
        
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
    }
    
    public override func prepareLayout() {
        trace()
        log("bounds = \(collectionView?.bounds ?? CGRect.zeroRect)")
        
        contentSizeAdjustment = CGSize.zeroSize
        contentOffsetAdjustment = CGPoint.zeroPoint
        
        let cvPtr = collectionView.map { unsafeAddressOf($0) } ?? UnsafePointer.null()
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
        let ret = layoutAttributes.filter {
            $0.frame.intersects(rect)
        }
        log("Requested layout attributes:\n\(layoutAttributesDescription(ret))")
        return ret
    }
    
    public override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        trace()
        
        if let existing = itemAttributesCache[indexPath] {
            log("Found attributes for \(indexPath.stringValue): \(existing.frame)")
            return existing
        }
        
        let (section, index) = unpack(indexPath: indexPath)
        if let info = sectionInfo(forSection: section) {
            let frame = { _ -> CGRect in
                switch (self.measuringItem, info[index]) {
                case (.Some(let (ip, rect)), _) where ip == indexPath:
                    return rect
                case (_, .Some(let item)):
                    return item.frame
                default:
                    return CGRect.zeroRect
                }
            }()
            
            let attributes = layoutAttributesType(forCellWithIndexPath: indexPath)
            attributes.hidden = flags.preparingLayout
            attributes.frame = frame
            attributes.zIndex = ZIndex.Item.rawValue
            attributes.backgroundColor = info.metrics.backgroundColor
            attributes.selectedBackgroundColor = info.metrics.selectedBackgroundColor
            attributes.tintColor = info.metrics.tintColor
            attributes.selectedTintColor = info.metrics.selectedTintColor
            
            log("Synthesized attributes for \(indexPath.stringValue): \(attributes.frame) (preparing layout \(flags.preparingLayout))")
            
            if !flags.preparingLayout {
                itemAttributesCache[indexPath] = attributes
            }
            
            return attributes
        }
        return nil
    }
    
    public override func layoutAttributesForSupplementaryViewOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        trace()
        
        let key = GridCacheKey(kind: kind, indexPath: indexPath)
        if let existing = supplementaryAttributesCache[key] {
            return existing
        }
        
        let (section, index) = unpack(indexPath: indexPath)
        let info = sectionInfo(forSection: section)
        let item = info?[kind, index]
        let frame = { _ -> CGRect in
            switch (self.measuringSupplement, item) {
            case (.Some(let (mKind, ip, rect)), _) where mKind == kind && ip == indexPath:
                return rect
            case (_, .Some(let item)):
                return item.frame
            default:
                return CGRect.zeroRect
            }
        }()
        
        let attributes = layoutAttributesType(forSupplementaryViewOfKind: kind, withIndexPath: indexPath)
        
        attributes.hidden = flags.preparingLayout
        attributes.frame = frame
        attributes.zIndex = ZIndex.Supplement.rawValue
        attributes.padding = item?.metrics.padding ?? UIEdgeInsetsZero
        attributes.backgroundColor = item?.metrics.backgroundColor ?? info?.metrics.backgroundColor
        attributes.selectedBackgroundColor = item?.metrics.selectedBackgroundColor ?? info?.metrics.selectedBackgroundColor
        attributes.tintColor = item?.metrics.tintColor ?? info?.metrics.tintColor
        attributes.selectedTintColor = item?.metrics.selectedTintColor ?? info?.metrics.selectedTintColor
        
        if !flags.preparingLayout {
            supplementaryAttributesCache[key] = attributes
        }
        
        return attributes
    }
    
    public override func layoutAttributesForDecorationViewOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        trace()
        
        let key = GridCacheKey(kind: kind, indexPath: indexPath)
        if let existing = decorationAttributesCache[key] {
            return existing
        }
        
        // FIXME: don't know… but returning nil crashes.
        return nil
    }
    
    public override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return true
    }
    
    public override func invalidationContextForBoundsChange(newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let oldBounds = collectionView?.bounds ?? CGRect.zeroRect
        let context = super.invalidationContextForBoundsChange(newBounds) as InvalidationContext
        
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

        for updateItem in updateItems as [UICollectionViewUpdateItem] {
            switch (updateItem.updateAction, updateItem.indexPathBeforeUpdate, updateItem.indexPathAfterUpdate) {
            case (.Insert, _, let indexPath) where indexPath.item == NSNotFound:
                insertedSections.addIndex(indexPath.section)
            case (.Insert, _, let indexPath):
                insertedIndexPaths.append(indexPath)
            case (.Delete, let indexPath, _) where indexPath.item == NSNotFound:
                removedSections.addIndex(indexPath.section)
            case (.Delete, let indexPath, _):
                removedIndexPaths.append(indexPath)
            case (.Reload, _, let indexPath) where indexPath.item == NSNotFound:
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
        return map(lazy(decorationAttributesCacheOld).filter {
            $0.0.kind == kind && self.decorationAttributesCache[$0.0] != nil
        }, { $0.0.indexPath })
    }
    
    public override func initialLayoutAttributesForAppearingDecorationElementOfKind(kind: String, atIndexPath decorationIndexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("initial decoration:\(kind) indexPath:\(decorationIndexPath.stringValue)")
        
        let key = GridCacheKey(kind: kind, indexPath: decorationIndexPath)
        let (section, _) = unpack(indexPath: decorationIndexPath)
        
        if var result = decorationAttributesCache[key]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureInitial(attributes: &result, inFromDirection: direction, shouldFadeIn: {
                contains(self.insertedSections, section) || (contains(self.reloadedSections, section) && self.decorationAttributesCacheOld[key] == nil)
            })
            
            return result
        }
        
        return nil
    }
    
    public override func finalLayoutAttributesForDisappearingDecorationElementOfKind(kind: String, atIndexPath decorationIndexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("final decoration:\(kind) indexPath:\(decorationIndexPath.stringValue)")
        
        let key = GridCacheKey(kind: kind, indexPath: decorationIndexPath)
        let (section, _) = unpack(indexPath: decorationIndexPath)
        
        if var result = decorationAttributesCacheOld[key]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureFinal(attributes: &result, outToDirection: direction, shouldFadeOut: {
                contains(self.removedSections, section) || (contains(self.reloadedSections, section) && self.decorationAttributesCache[key] == nil)
            })
            
            return result
        }
        
        return nil
    }
    
    public override func initialLayoutAttributesForAppearingSupplementaryElementOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("initial supplement:\(kind) indexPath:\(indexPath.stringValue)")
        
        let key = GridCacheKey(kind: kind, indexPath: indexPath)
        let (section, _) = unpack(indexPath: indexPath)
        
        if var result = supplementaryAttributesCache[key]?.copy() as? Attributes {
            if kind == SupplementKind.Placeholder.rawValue {
                configureInitial(attributes: &result, inFromDirection: .Default, shouldFadeIn: { true })
            } else {
                let direction = updateSectionDirections[section] ?? .Default
                let inserted = contains(insertedSections, section)
                let offsets = direction != .Default && inserted
                
                configureInitial(attributes: &result, inFromDirection: direction, makeFrameAdjustments: offsets, shouldFadeIn: {
                    inserted || (contains(self.reloadedSections, section) && self.supplementaryAttributesCacheOld[key] == nil)
                })
            }
            
            return result
        }
        
        return nil
    }
    
    public override func finalLayoutAttributesForDisappearingSupplementaryElementOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("final supplement:\(kind) indexPath:\(indexPath.stringValue)")
        
        let key = GridCacheKey(kind: kind, indexPath: indexPath)
        let (section, _) = unpack(indexPath: indexPath)
        
        if var result = supplementaryAttributesCacheOld[key]?.copy() as? Attributes {
            if kind == SupplementKind.Placeholder.rawValue {
                configureFinal(attributes: &result, outToDirection: .Default, shouldFadeOut: { true })
            } else {
                let direction = updateSectionDirections[section] ?? .Default
                configureFinal(attributes: &result, outToDirection: direction, shouldFadeOut: {
                    contains(self.removedSections, section) || contains(self.reloadedSections, section)
                })
            }
            
            return result
        }
        
        return nil
    }
    
    public override func initialLayoutAttributesForAppearingItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("initial indexPath:\(indexPath.stringValue)")
        
        let (section, _) = unpack(indexPath: indexPath)
        
        if var result = itemAttributesCache[indexPath]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureInitial(attributes: &result, inFromDirection: direction, shouldFadeIn: {
                contains(self.insertedSections, section) || self.insertedIndexPaths.contains(indexPath) || (contains(self.reloadedSections, section) && self.itemAttributesCacheOld[indexPath] == nil)
            })
            
            return result
        }
        
        return nil
    }
    
    public override func finalLayoutAttributesForDisappearingItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        log("final indexPath:\(indexPath.stringValue)")
        
        let (section, _) = unpack(indexPath: indexPath)
        
        if var result = itemAttributesCacheOld[indexPath]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureFinal(attributes: &result, outToDirection: direction, shouldFadeOut: {
                self.removedIndexPaths.contains(indexPath) || contains(self.removedSections, section) || (contains(self.reloadedSections, section) && self.itemAttributesCache[indexPath] == nil)
            })
            
            return result
        }
        
        return nil
    }
    
    // MARK: Internal
    
    private func snapshotMetrics() -> [Section: SectionMetrics] {
        return dataSource?.snapshotMetrics() ?? [:]
    }
    
    private func resetLayoutInfo() {
        sections.removeAll(keepCapacity: true)
        globalSection = nil
        
        globalSectionBackground = nil
        nonPinnableGlobalAttributes.removeAll()
        pinnableAttributes.removeAll()
        
        itemAttributesCacheOld.removeAll()
        swap(&itemAttributesCache, &itemAttributesCacheOld)
        
        supplementaryAttributesCacheOld.removeAll()
        swap(&supplementaryAttributesCache, &supplementaryAttributesCacheOld)
        
        decorationAttributesCacheOld.removeAll()
        swap(&decorationAttributesCache, &decorationAttributesCacheOld)
    }
    
    private func createLayoutInfoFromDataSource() {
        trace()
        
        resetLayoutInfo()
        
        let metricsBySection = snapshotMetrics()
        
        let bounds = collectionView?.bounds
        let insets = collectionView?.contentInset ?? UIEdgeInsetsZero
        let height = bounds.map { $0.height - insets.top - insets.bottom } ?? 0
        let numberOfSections = collectionView?.numberOfSections() ?? 0
        
        func fromMetrics(color: UIColor?) -> UIColor? {
            if color == UIColor.clearColor() { return nil }
            return color
        }
        
        let build = { (section: Section, var metrics: SectionMetrics) -> SectionInfo in
            metrics.backgroundColor = fromMetrics(metrics.backgroundColor)
            metrics.selectedBackgroundColor = fromMetrics(metrics.selectedBackgroundColor)
            metrics.tintColor = fromMetrics(metrics.tintColor)
            metrics.selectedTintColor = fromMetrics(metrics.selectedTintColor)
            metrics.separatorColor = fromMetrics(metrics.separatorColor)
            metrics.numberOfColumns = min(metrics.numberOfColumns ?? 0, 1)
            
            var info = SectionInfo(metrics: metrics)
            
            for inSuplMetric in metrics.supplementaryViews {
                switch (inSuplMetric.measurement, inSuplMetric.kind) {
                case (.None, SupplementKind.Footer.rawValue):
                    continue
                default:
                    break
                }
                
                var suplMetric = inSuplMetric
                
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
            
            switch (section, metrics.hasPlaceholder) {
            case (_, true):
                // A section can either have a placeholder or items. Arbitrarily deciding the placeholder takes precedence.
                var placeholder = SupplementaryMetrics(kind: SupplementKind.Placeholder)
                placeholder.measurement = .Static(height)
                info.addSupplementalItem(placeholder)
            case (.Index(let idx), _):
                info.addItems(self.collectionView?.numberOfItemsInSection(idx) ?? 0)
            default: break
            }
            
            return info
        }
        
        log("number of sections = \(numberOfSections)")
        
        globalSection = metricsBySection[.Global].map { build(.Global, $0) }
        sections = map(0..<numberOfSections) { idx in
            let section = Section.Index(idx)
            return build(section, metricsBySection[section]!)
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
        layoutAttributes.removeAll()
        
        let contentInset = collectionView?.contentInset ?? UIEdgeInsetsZero
        let contentOffsetY = collectionView.map { $0.contentOffset.y + contentInset.top } ?? 0
        
        let viewportSize = collectionView?.bounds.rectByInsetting(insets: contentInset).size ?? CGSize.zeroSize
        var layoutRect = CGRect(origin: CGPoint.zeroPoint, size: viewportSize)
        var start = layoutRect.origin
        
        var shouldInvalidate = false
        let measureSupplement = { (kind: String, indexPath: NSIndexPath, measuringFrame: CGRect) -> CGSize in
            shouldInvalidate |= true
            self.measuringSupplement = (kind, indexPath, measuringFrame)
            return self.dataSource?.sizeFittingSize(measuringFrame.size, supplementaryElementOfKind: kind, indexPath: indexPath, collectionView: self.collectionView!) ?? measuringFrame.size
        }
        
        // build global section
        globalSection?.layout(rect: layoutRect, nextStart: &start) {
            measureSupplement($0, NSIndexPath($1), $2)
        }
        
        if let section = globalSection {
            addLayoutAttributes(forSection: .Global, withInfo: section)
        }
        
        // build all sections
        sections = sections.mapWithIndex { (sectionIndex, var section) -> SectionInfo in
            layoutRect.size.height = max(0, layoutRect.height - start.y + layoutRect.minY)
            layoutRect.origin = start
            
            section.layout(rect: layoutRect, nextStart: &start, measureSupplement: {
                measureSupplement($0, NSIndexPath(sectionIndex, $1), $2)
            }, measureItem: {
                let indexPath = NSIndexPath(sectionIndex, $0)
                self.measuringItem = (indexPath, $1)
                return self.dataSource?.sizeFittingSize($1.size, itemAtIndexPath: indexPath, collectionView: self.collectionView!) ?? $1.size
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
        
        log("prepared layout attributes:\n\(layoutAttributesDescription(layoutAttributes))")
        
        // But if the headers changed, we need to invalidate…
        if (shouldInvalidate) {
            invalidateLayout()
        }
    }
    
    private func addSeparator(kind: DecorationKind = .RowSeparator, bit: SeparatorOptions = .Supplements, toRect getRect: @autoclosure () ->  CGRect, edge: CGRectEdge = .MaxYEdge, indexPath getIndexPath: @autoclosure () -> NSIndexPath, metrics: SectionMetrics) -> Attributes? {
        let color = metrics.separatorColor
        if color == nil || !contains(metrics.separators, bit) { return nil }
        
        let ip = getIndexPath()
        let frame = getRect().separatorRect(edge: edge, thickness: hairline)
        
        let separatorAttributes = layoutAttributesType(forDecorationViewOfKind: kind.rawValue, withIndexPath: ip)
        separatorAttributes.frame = frame
        separatorAttributes.backgroundColor = color
        separatorAttributes.zIndex = ZIndex.Decoration.rawValue
        layoutAttributes.append(separatorAttributes)
        
        let cacheKey = GridCacheKey(kind: kind.rawValue, indexPath: ip)
        decorationAttributesCache[cacheKey] = separatorAttributes
        
        return separatorAttributes
    }
    
    private func addSupplementAttributes(#kind: String, indexPath getIndexPath: @autoclosure () -> NSIndexPath, info item: SupplementInfo, metrics section: SectionMetrics) -> Attributes? {
        // ignore headers if there are no items and the header isn't a global header
        if item.metrics.isHidden || item.frame.isEmpty { return nil }
        
        let ip = getIndexPath()
        
        let attribute = layoutAttributesType(forSupplementaryViewOfKind: kind, withIndexPath: ip)
        attribute.frame = item.frame
        attribute.unpinned = item.frame.minY
        attribute.zIndex = ZIndex.Supplement.rawValue
        attribute.backgroundColor = item.metrics.backgroundColor ?? section.backgroundColor
        attribute.selectedBackgroundColor = item.metrics.selectedBackgroundColor ?? section.selectedBackgroundColor
        attribute.tintColor = item.metrics.tintColor ?? section.tintColor
        attribute.selectedTintColor = item.metrics.selectedTintColor ?? section.selectedTintColor
        attribute.padding = item.metrics.padding
        layoutAttributes.append(attribute)
        
        let key = GridCacheKey(kind: kind, indexPath: ip)
        supplementaryAttributesCache[key] = attribute
        
        return attribute
    }
    
    private func addSupplementAttributes<T: RawRepresentable where T.RawValue == String>(kind: SupplementKind = .Header, indexPath getIndexPath: @autoclosure () -> NSIndexPath, info item: SupplementInfo, metrics section: SectionMetrics) -> Attributes? {
        return addSupplementAttributes(kind: kind.rawValue, indexPath: getIndexPath, info: item, metrics: section)
    }
    
    private func addLayoutAttributes(forSection section: Section, withInfo info: SectionInfo) {
        let numberOfSections = collectionView?.numberOfSections() ?? 0
        
        let afterSectionBit = { () -> SeparatorOptions in
            switch section {
            case .Index(let idx):
                return idx + 1 < numberOfSections ? .AfterSections : .AfterLastSection
            case .Global:
                return .AfterSections
            }
        }()
        
        let indexPath = { (idx: Int) -> NSIndexPath in
            switch section {
            case .Global:
                return NSIndexPath(idx)
            case .Index(let section):
                return NSIndexPath(section, idx)
            }
        }
        
        // Add the background decoration attribute
        switch (section, info.metrics.backgroundColor) {
        case (.Global, .Some(let color)):
            let ip = indexPath(0)
            let kind = DecorationKind.GlobalHeaderBackground.rawValue
            let frame = info.frame
            
            let attribute = layoutAttributesType(forDecorationViewOfKind: kind, withIndexPath: ip)
            attribute.frame = frame
            attribute.unpinned = frame.minY
            attribute.zIndex = ZIndex.Item.rawValue
            attribute.backgroundColor = color
            
            layoutAttributes.append(attribute)
            globalSectionBackground = attribute
            
            let cacheKey = GridCacheKey(kind: kind, indexPath: ip)
            decorationAttributesCache[cacheKey] = attribute
        default:
            globalSectionBackground = nil
        }
        
        // Helper for laying out supplements
        func appendPinned(attribute: Attributes, shouldPin: Bool) {
            if shouldPin {
                pinnableAttributes.append(attribute, forKey: section)
            } else if section == .Global {
                nonPinnableGlobalAttributes.append(attribute)
            }
        }
        
        // Lay out headers
        for (kind, idx, item) in info[.Header] {
            if info.numberOfItems == 0 && !item.metrics.isVisibleWhileShowingPlaceholder { continue }
            
            if let attribute = addSupplementAttributes(kind: kind, indexPath: indexPath(idx), info: item, metrics: info.metrics) {
                appendPinned(attribute, item.metrics.shouldPin)
                
                // Separators after global headers, before regular headers
                if idx > 0 {
                    if let separator = addSeparator(kind: .HeaderSeparator, toRect: attribute.frame, indexPath: attribute.indexPath, metrics: info.metrics) {
                        appendPinned(separator, item.metrics.shouldPin)
                    }
                }
            }
        }
        
        // Separator after non-global headers
        let numberOfHeaders = info.count(supplements: .Header) ?? 0
        switch (numberOfHeaders, info.numberOfItems) {
        case (0, 0):
            break
        case (0, let items) where items != 0:
            addSeparator(kind: .HeaderSeparator, bit: .BeforeSections, toRect: info.headersRect, indexPath: indexPath(0), metrics: info.metrics)
        case (let headers, 0) where headers != 0:
            addSeparator(kind: .HeaderSeparator, bit: afterSectionBit, toRect: info.headersRect, indexPath: indexPath(numberOfHeaders), metrics: info.metrics)
        default:
            addSeparator(kind: .HeaderSeparator, bit: .Supplements,
                toRect: info.headersRect.rectByInsetting(insets: info.metrics.groupPadding),
                indexPath: indexPath(numberOfHeaders), metrics: info.metrics)
        }
        
        // Lay out rows
        let numberOfColumns = info.metrics.numberOfColumns ?? 1
        for (rowIndex, row) in enumerate(info.rows) {
            if row.items.isEmpty { continue }
            
            let sepInsets = info.metrics.separatorInsets ?? UIEdgeInsetsZero
            
            if rowIndex > 0 {
                // If there's a separator, add it above the current row…
                addSeparator(kind: .RowSeparator, bit: .Rows,
                    toRect: row.frame.rectByInsetting(insets: sepInsets.without(.Top | .Bottom)), edge: .MinYEdge,
                    indexPath: indexPath(rowIndex * numberOfColumns), metrics: info.metrics)
            }
            
            for (columnIndex, item) in enumerate(row.items) {
                let ip = indexPath(rowIndex * numberOfColumns + columnIndex)
                
                if columnIndex > 0 {
                    addSeparator(kind: .ColumnSeparator, bit: .Columns,
                        toRect: item.frame.rectByInsetting(insets: sepInsets.without(.Left | .Right)), edge: .MinXEdge,
                    indexPath: ip, metrics: info.metrics)
                }
                
                let attribute = layoutAttributesType(forCellWithIndexPath: ip)
                attribute.frame = item.frame
                attribute.zIndex = ZIndex.Item.rawValue
                attribute.backgroundColor = info.metrics.backgroundColor
                attribute.selectedBackgroundColor = info.metrics.selectedBackgroundColor
                attribute.backgroundColor = info.metrics.tintColor
                attribute.selectedBackgroundColor = info.metrics.selectedTintColor
                attribute.columnIndex = columnIndex
                layoutAttributes.append(attribute)
                                
                itemAttributesCache[ip] = attribute
            }
        }
        
        // Lay out other supplements
        for (kind, idx, item) in info[.Footer] {
            if let attribute = addSupplementAttributes(kind: kind, indexPath: indexPath(idx), info: item, metrics: info.metrics) {
                addSeparator(kind: .FooterSeparator, bit: .Supplements, toRect: item.frame, edge: .MinYEdge, indexPath: attribute.indexPath, metrics: info.metrics)
            }
        }
        
        for (kind, idx, item) in info[.AllOther] {
            addSupplementAttributes(kind: kind, indexPath: indexPath(idx), info: item, metrics: info.metrics)
        }
        
        
        // Add the section separator below this section provided it's not the last section (or if the section explicitly says to)
        switch (section, info.numberOfItems) {
        case (.Index, let items) where items != 0:
            addSeparator(bit: afterSectionBit, toRect: info.frame, indexPath: indexPath(items), metrics: info.metrics)
        default: break
        }
    }
    
    private func updateSpecialAttributes() {
        let countSections = collectionView?.numberOfSections()
        if countSections < 1 { return }
        
        let resetPinnable = { (attributes: Attributes) -> () in
            attributes.pinned = false
            if let unpinned = attributes.unpinned {
                attributes.frame.origin.y = unpinned
            }
        }
        
        let normalContentOffset = collectionView?.contentOffset ?? CGPoint.zeroPoint
        let contentOffset = flags.useCollectionViewContentOffset ? normalContentOffset : targetContentOffsetForProposedContentOffset(normalContentOffset)
        let minY = collectionView?.contentInset.top ?? 0
        
        var pinnableY = minY + contentOffset.y
        var nonPinnableY = pinnableY
        
        // pin the attributes starting at minY as long a they don't cross maxY and return the new minY
        let applyTopPinning = { (attributes: Attributes) -> () in
            if attributes.frame.minY < pinnableY {
                attributes.frame.origin.y = pinnableY
                pinnableY = attributes.frame.maxY
            }
        }
        
        let applyBottomPinning = { (attributes: Attributes) -> () in
            if attributes.frame.maxY < nonPinnableY {
                attributes.frame.origin.y = nonPinnableY - attributes.frame.height
                nonPinnableY = attributes.frame.minY
            }
        }
        
        let finalizePinning = { (attributes: Attributes, zIndex: ZIndex, offset: Int) -> () in
            attributes.zIndex = zIndex.rawValue - offset - 1
            if let unpinned = attributes.unpinned {
                attributes.pinned = attributes.frame.minY !~== unpinned
            } else {
                attributes.pinned = false
            }
        }
        
        // Pin the headers as appropriate
        for (idx, info) in enumerate(pinnableAttributes[.Global]) {
            resetPinnable(info)
            applyTopPinning(info)
            finalizePinning(info, .SupplementPinned, idx)
        }
        
        nonPinnableGlobalAttributes = nonPinnableGlobalAttributes.mapWithIndexReversed {
            resetPinnable($1)
            applyBottomPinning($1)
            finalizePinning($1, .SupplementPinned, $0)
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
                    resetPinnable(attr)
                }
                
                let frame = sections[idx].frame
                if !foundSection && frame.minY <= pinnableY && pinnableY <= frame.maxY {
                    foundSection = true
                    
                    for (idx, attr) in enumerate(values) {
                        applyTopPinning(attr)
                        finalizePinning(attr, .OverlapPinned, idx)
                    }
                }
            case .Global: break
            }
        }
    }
    
    // MARK: Helpers
    
    private func configureInitial(inout #attributes: Attributes, inFromDirection direction: SectionOperationDirection = .Default, makeFrameAdjustments: Bool = true, shouldFadeIn shouldFade: (() -> Bool)? = nil) {
        var endFrame = attributes.frame
        var endAlpha = attributes.alpha
        let bounds = collectionView!.bounds
        
        switch direction {
        case .Default:
            if let shouldFade = shouldFade {
                if shouldFade() {
                    endAlpha = 0
                }
            }
            break
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
    
    private func configureFinal(inout #attributes: Attributes, outToDirection direction: SectionOperationDirection = .Default, shouldFadeOut shouldFade: (() -> Bool)? = nil) {
        var endFrame = attributes.frame
        var endAlpha = attributes.alpha
        let bounds = collectionView!.bounds
        
        switch direction {
        case .Default:
            if let shouldFade = shouldFade {
                if shouldFade() { endAlpha = 0 }
            }
            break
        case .Left:
            endFrame.origin.x += bounds.width
            endAlpha = 0
        case .Right:
            endFrame.origin.x -= bounds.width
            endAlpha = 0
        }
        
        if attributes.pinned {
            endFrame.origin.x += contentOffsetAdjustment.x
            endFrame.origin.y = max(attributes.unpinned ?? CGFloat.min, endFrame.minY + contentOffsetAdjustment.y)
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
    
    private func unpack(#indexPath: NSIndexPath) -> (Section, Int) {
        if indexPath.length == 1 {
            return (.Global, indexPath[0])
        }
        return (.Index(indexPath[0]), indexPath[1])
    }
    
}

extension GridLayout: DebugPrintable {
    
    private func layoutAttributesDescription(attributes: [Attributes]) -> String {
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
    
    private var layoutAttributesDescription: String {
        return join("\n", layoutAttributes.map { attr in
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
                updateSectionDirections[.Index(sectionIndex)] = direction
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

private func contains(indexSet: NSIndexSet, section: Section) -> Bool {
    switch section {
    case .Global:
        return false
    case .Index(let idx):
        return indexSet.containsIndex(idx)
    }
}
