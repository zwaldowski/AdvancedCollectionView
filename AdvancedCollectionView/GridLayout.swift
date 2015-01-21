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

public class GridLayout: UICollectionViewLayout {
    
    public let DefaultRowHeight = CGFloat(44)

    public enum DecorationKind: String {
        case RowSeparator = "rowSeparator"
        case ColumnSeparator = "columnSeparator"
        case HeaderSeparator = "headerSeparator"
        case FooterSeparator = "footerSeparator"
        case GlobalHeaderBackground = "globalHeaderBackground"
    }
    
    public enum SupplementKind: String {
        case Header = "UICollectionElementKindSectionHeader"
        case Footer = "UICollectionElementKindSectionFooter"
        case SectionGap = "sectionGap"
        case AtopHeaders = "atopHeaders"
        case AtopItems = "atopItems"
        case Placeholder = "placeholder"
    }
    
    typealias Attributes = GridLayoutAttributes
    typealias InvalidationContext = GridLayoutInvalidationContext
    typealias SupplementCacheKey = GridLayoutCacheKey<SupplementKind>
    typealias DecorationCacheKey = GridLayoutCacheKey<DecorationKind>
    
    public enum ZIndex: Int {
        case Item = 1
        case Supplement = 100
        case Decoration = 1000
        case SupplementPinned = 10000
    }
    
    private var layoutSize = CGSize.zeroSize
    private var oldLayoutSize = CGSize.zeroSize
    
    private var layoutAttributes = [Attributes]()
    private var sections = [SectionInfo]()
    private var globalSection: SectionInfo?
    
    private var globalSectionBackground: Attributes?
    private var nonPinnableGlobalAttributes = [Attributes]()
    
    private var supplementaryAttributesCache = [SupplementCacheKey:Attributes]()
    private var supplementaryAttributesCacheOld = [SupplementCacheKey:Attributes]()
    private var decorationAttributesCache = [DecorationCacheKey:Attributes]()
    private var decorationAttributesCacheOld = [DecorationCacheKey:Attributes]()
    private var itemAttributesCache = [NSIndexPath:Attributes]()
    private var itemAttributesCacheOld = [NSIndexPath:Attributes]()
    
    private var updateSectionDirections = [Section: SectionOperationDirection]()
    private var insertedIndexPaths = Set<NSIndexPath>()
    private var removedIndexPaths = Set<NSIndexPath>()
    private var insertedSections = NSMutableIndexSet()
    private var removedSections = NSMutableIndexSet()
    private var reloadedSections = NSMutableIndexSet()
    
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

    // MARK:

    func commonInit() {
        registerClass(AAPLGridLayoutColorView.self, forDecorationView: DecorationKind.RowSeparator)
        registerClass(AAPLGridLayoutColorView.self, forDecorationView: DecorationKind.ColumnSeparator)
        registerClass(AAPLGridLayoutColorView.self, forDecorationView: DecorationKind.HeaderSeparator)
        registerClass(AAPLGridLayoutColorView.self, forDecorationView: DecorationKind.FooterSeparator)
        registerClass(AAPLGridLayoutColorView.self, forDecorationView: DecorationKind.GlobalHeaderBackground)
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
    
    public func invalidateLayout(forItemAtIndexPath indexPath: NSIndexPath) {
        var section = sections[indexPath.section]
        var item = section.items[indexPath.item]
        
        let fittingSize = CGSize(width: item.frame.width, height: UILayoutFittingExpandedSize.height)
        item.frame.size = collectionView?.cellForItemAtIndexPath(indexPath)?.aapl_preferredLayoutSizeFittingSize(fittingSize) ?? CGSize.zeroSize
        
        section.items[indexPath.item] = item
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
    
    private var collectionViewInfo: (UICollectionView?, CollectionViewDataSourceGridLayout?) {
        // :-(
        if let collectionView = collectionView {
            return (collectionView, collectionView.dataSource as? DataSource)
        }
        return (nil, nil)
    }
    
    // MARK: UICollectionViewLayout
    
    override public class func layoutAttributesClass() -> AnyClass {
        return Attributes.self
    }
    
    override public class func invalidationContextClass() -> AnyClass {
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
        
        super.invalidateLayoutWithContext(context)
    }
    
    public override func prepareLayout() {
        contentSizeAdjustment = CGSize.zeroSize
        contentOffsetAdjustment = CGPoint.zeroPoint
        
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
        filterSpecialAttributes()
        return layoutAttributes.filter {
            $0.frame.intersects(rect)
        }
    }
    
    public override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        if let existing = itemAttributesCache[indexPath] {
            return existing
        }
        
        let globalInfo = indexPath.globalInfo
        let section = sectionInfo(globalInfo.section)!
        if globalInfo.item >= section.items.count { return nil }
        let item = section.items[globalInfo.item]

        let (collectionView, dataSource) = collectionViewInfo
        var attributes = layoutAttributesType(forCellWithIndexPath: indexPath)
        
        attributes.hidden = flags.preparingLayout
        attributes.frame = item.frame
        attributes.zIndex = ZIndex.Item.rawValue
        attributes.backgroundColor = section.metrics.backgroundColor
        attributes.selectedBackgroundColor = section.metrics.selectedBackgroundColor
        attributes.tintColor = section.metrics.tintColor
        attributes.selectedTintColor = section.metrics.selectedTintColor
        attributes.columnIndex = item.columnIndex
        
        if !flags.preparingLayout {
            itemAttributesCache[indexPath] = attributes
        }
        
        return attributes
    }
    
    public override func layoutAttributesForSupplementaryViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        let key = SupplementCacheKey(indexPath: indexPath, representedElementKind: elementKind)
        if let existing = supplementaryAttributesCache[key] {
            return existing
        }
        
        let globalInfo = indexPath.globalInfo
        let section = sectionInfo(globalInfo.section)!
        let item = section.supplementalItems[elementKind, globalInfo.item]
        
        let (collectionView, dataSource) = collectionViewInfo
        var attributes = layoutAttributesType(forSupplementaryViewOfKind: elementKind, withIndexPath: indexPath)
        
        attributes.hidden = flags.preparingLayout
        attributes.frame = item?.frame ?? CGRect.zeroRect
        attributes.zIndex = ZIndex.Supplement.rawValue
        attributes.padding = item?.metrics.padding ?? UIEdgeInsetsZero
        attributes.backgroundColor = item?.metrics.backgroundColor ?? section.metrics.backgroundColor
        attributes.selectedBackgroundColor = item?.metrics.selectedBackgroundColor ?? section.metrics.selectedBackgroundColor
        attributes.tintColor = item?.metrics.tintColor ?? section.metrics.tintColor
        attributes.selectedTintColor = item?.metrics.selectedTintColor ?? section.metrics.selectedTintColor
        
        if !flags.preparingLayout {
            supplementaryAttributesCache[key] = attributes
        }
        
        return nil
    }
    
    public override func layoutAttributesForDecorationViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        let key = DecorationCacheKey(indexPath: indexPath, representedElementKind: elementKind)
        if let existing = decorationAttributesCache[key] {
            return existing
        }
        
        // FIXME: don't know… but returning nil crashes.
        return nil
    }
    
    public override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        let oldBounds = collectionView?.bounds ?? CGRect.zeroRect
        if newBounds.size.width != oldBounds.size.width { return true }
        return newBounds.origin == oldBounds.origin
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
        return flags.preparingLayout ? oldLayoutSize : layoutSize
    }
    
    public override func prepareForCollectionViewUpdates(updateItems: [AnyObject]!) {
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
        insertedIndexPaths.removeAll()
        removedIndexPaths.removeAll()
        insertedSections.removeAllIndexes()
        removedSections.removeAllIndexes()
        reloadedSections.removeAllIndexes()
        updateSectionDirections.removeAll()
        super.finalizeCollectionViewUpdates()
    }
    
    public override func indexPathsToDeleteForDecorationViewOfKind(elementKind: String) -> [AnyObject] {
        let kind = DecorationKind(rawValue: elementKind)!
        return lazy(decorationAttributesCacheOld).filter {
            $0.0.kind == kind && self.decorationAttributesCache[$0.0] != nil
        }.map {
            $0.0.indexPath
        }.array
    }
    
    // MARK: CV done
    
    public override func initialLayoutAttributesForAppearingDecorationElementOfKind(elementKind: String, atIndexPath decorationIndexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        let key = DecorationCacheKey(indexPath: decorationIndexPath, representedElementKind: elementKind)
        let section = decorationIndexPath.globalInfo.section
        
        if var result = decorationAttributesCache[key]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureInitial(attributes: &result, inFromDirection: direction, shouldFadeIn: {
                contains(self.insertedSections, section) || (contains(self.reloadedSections, section) && self.decorationAttributesCacheOld[key] == nil)
            })
            
            return result
        }
        
        return nil
    }
    
    public override func finalLayoutAttributesForDisappearingDecorationElementOfKind(elementKind: String, atIndexPath decorationIndexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        let key = DecorationCacheKey(indexPath: decorationIndexPath, representedElementKind: elementKind)
        let section = decorationIndexPath.globalInfo.section
        
        if var result = decorationAttributesCacheOld[key]?.copy() as? Attributes {
            let direction = updateSectionDirections[section] ?? .Default
            
            configureFinal(attributes: &result, outToDirection: direction, shouldFadeOut: {
                contains(self.removedSections, section) || (contains(self.reloadedSections, section) && self.decorationAttributesCache[key] == nil)
            })
            
            return result
        }
        
        return nil
    }
    
    public override func initialLayoutAttributesForAppearingSupplementaryElementOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        let kind = SupplementKind(rawValue: elementKind)!
        let key = SupplementCacheKey(indexPath: indexPath, kind: kind)
        let section = indexPath.globalInfo.section
        
        if var result = supplementaryAttributesCache[key]?.copy() as? Attributes {
            if kind == .Placeholder {
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
    
    public override func finalLayoutAttributesForDisappearingSupplementaryElementOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        let kind = SupplementKind(rawValue: elementKind)!
        let key = SupplementCacheKey(indexPath: indexPath, kind: kind)
        let section = indexPath.globalInfo.section
        
        if var result = supplementaryAttributesCacheOld[key]?.copy() as? Attributes {
            if kind == .Placeholder {
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
        let section = indexPath.globalInfo.section
        
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
        let section = indexPath.globalInfo.section
        
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
    
    private func snapshotMetrics() -> [Section: SectionMetrics]? {
        return collectionViewInfo.1?.snapshotMetrics()
    }
    
    private func resetLayoutInfo() {
        sections.removeAll(keepCapacity: true)
        globalSection = nil
        globalSectionBackground = nil
        
        itemAttributesCacheOld.removeAll()
        swap(&itemAttributesCache, &itemAttributesCacheOld)
        
        supplementaryAttributesCacheOld.removeAll()
        swap(&supplementaryAttributesCache, &supplementaryAttributesCacheOld)
        
        decorationAttributesCacheOld.removeAll()
        swap(&decorationAttributesCache, &decorationAttributesCacheOld)
    }
    
    private func createLayoutInfoFromDataSource() {
        
    }
    
    private func addLayoutAttributes(forSection section: Section, withInfo info: SectionInfo, dataSource: CollectionViewDataSourceGridLayout) {
        
    }
    
    private func height(ofAttributes attributes: [Attributes]) -> CGFloat {
        return 0
    }
    
    private func buildLayout() {
        
    }
    
    private func resetPinnable(inout #attributes: [Attributes]) {
        
    }
    
    private func applyBottomPinning(inout #attributes: [Attributes], maxY: CGFloat) {
        
    }
    
    private func applyTopPinning(inout #attributes: [Attributes], minY: CGFloat) {
        
    }
    
    private func finalizePinned(inout #attributes: [Attributes], zIndex: Int) {
        
    }
    
    private func firstSectionOverlapping(#yOffset: CGFloat) -> SectionInfo? {
        return nil
    }
    
    private func filterSpecialAttributes() {
        
    }
    
    // MARK:
    
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
        
        switch attributes.pinned {
        case let .Pinned(unpinnedY):
            endFrame.origin.x += contentOffsetAdjustment.x
            endFrame.origin.y = max(unpinnedY, endFrame.minY + contentOffsetAdjustment.y)
            break
        case .Unpinned:
            endFrame.offset(dx: contentOffsetAdjustment.x, dy: contentOffsetAdjustment.y)
            break
        }
        
        attributes.alpha = endAlpha
        attributes.frame = endFrame
    }
    
    private func sectionInfo(forIndexPath indexPath: NSIndexPath) -> SectionInfo! {
        switch indexPath.globalInfo {
        case (.Global, _):
            return globalSection
        case (.Index(let section), _):
            return sections[section]
        }
    }
    
    private func sectionInfo(section: Section) -> SectionInfo? {
        switch section {
        case .Global:
            return globalSection
        case .Index(let section):
            return sections[section]
        }
    }
    
}

extension GridLayout: DebugPrintable {
    
    public override var debugDescription: String {
        return ""
    }
    
}

extension GridLayout: DataSourcePresenter {
    
    public func dataSourceWillInsertSections(dataSource: DataSource, indexes: NSIndexSet, direction: SectionOperationDirection) {
        for sectionIndex in indexes {
            updateSectionDirections[.Index(sectionIndex)] = direction
        }
    }
    
    public func dataSourceWillRemoveSections(dataSource: DataSource, indexes: NSIndexSet, direction: SectionOperationDirection) {
        for sectionIndex in indexes {
            updateSectionDirections[.Index(sectionIndex)] = direction
        }
    }
    
    public func dataSourceWillMoveSection(dataSource: DataSource, from section: Int, to newSection: Int, direction: SectionOperationDirection) {
        updateSectionDirections[.Index(section)] = direction
        updateSectionDirections[.Index(newSection)] = direction
    }
    
    public func dataSourceDidReloadGlobalSection(dataSource: DataSource) {
        invalidateLayoutForGlobalSection()
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
