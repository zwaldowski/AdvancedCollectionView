//
//  GridLayoutInfo.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/22/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

struct GridLayoutCacheKey<Kind: RawRepresentable where Kind.RawValue == String> {
    let kind: Kind
    let indexPath: NSIndexPath
    
    init(kind: Kind, indexPath: NSIndexPath) {
        self.kind = kind
        self.indexPath = indexPath
    }
    
    init!(representedElementKind: String, indexPath: NSIndexPath) {
        if let kind = Kind(rawValue: representedElementKind) {
            self.init(kind: kind, indexPath: indexPath)
        } else {
            return nil
        }
    }
    
}

func ==<Kind: RawRepresentable where Kind.RawValue == String>(lhs: GridLayoutCacheKey<Kind>, rhs: GridLayoutCacheKey<Kind>) -> Bool {
    return lhs.indexPath === rhs.indexPath ||
        lhs.kind.rawValue == rhs.kind.rawValue ||
        lhs.indexPath == rhs.indexPath
}

extension GridLayoutCacheKey: Hashable {
    
    var hashValue: Int {
        return 31 &* indexPath.hashValue &+ kind.rawValue.hashValue
    }
    
}

extension GridLayoutCacheKey: DebugPrintable {
    
    var debugDescription: String {
        let commaSeparated = join(", ", map(indexPath) { String($0) })
        return "\(kind)@{\(commaSeparated)}"
    }
    
}

// MARK: -

extension SectionMetrics {
    
    var groupPadding: UIEdgeInsets {
        return padding?.without(.Left | .Right) ?? UIEdgeInsetsZero
    }
    
    var itemPadding: UIEdgeInsets? {
        return padding?.without(.Top | .Bottom) ?? UIEdgeInsetsZero
    }
    
    var layoutSlicingEdge: CGRectEdge {
        let layout = itemLayout ?? .Natural
        switch layout {
        case .Natural:
            return UIUserInterfaceLayoutDirection.userLayoutDirection == .LeftToRight ? .MinXEdge : .MaxXEdge
        case .NaturalReverse:
            return UIUserInterfaceLayoutDirection.userLayoutDirection == .RightToLeft ? .MinXEdge : .MaxXEdge
        case .LeadingToTrailing:
            return .MinXEdge
        case .TrailingToLeading:
            return .MaxXEdge
        }
    }
    
}

// MARK: -

struct SupplementInfo {
    
    let metrics: SupplementaryMetrics
    private(set) var frame = CGRect.zeroRect
    private(set) var measurement = ElementLength.None
    
    init(metrics: SupplementaryMetrics) {
        self.metrics = metrics
    }
    
}

struct ItemInfo {
    
    private(set) var frame = CGRect.zeroRect
    private(set) var measurement = ElementLength.None
    
    private init() {}
    
}

struct RowInfo {
    
    let items: Slice<ItemInfo>
    let frame = CGRect.zeroRect
    
    private init(items: Slice<ItemInfo>, frame: CGRect) {
        self.items = items
        self.frame = frame
    }
    
}

struct SectionInfo {
    
    typealias Attributes = GridLayoutAttributes
    typealias SupplementalItemsMap = Multimap<String, SupplementInfo>
    
    let metrics: SectionMetrics
    private(set) var frame = CGRect.zeroRect
    private(set) var items = [ItemInfo]()
    private(set) var rows = [RowInfo]() // ephemeral
    private(set) var supplementalItems = SupplementalItemsMap()
    private(set) var headersRect = CGRect.zeroRect
    
    init(metrics: SectionMetrics) {
        self.metrics = metrics
    }
    
}

// MARK: Attributes access

extension SectionInfo {
    
    enum Supplement {
        case Header
        case Footer
        case Named(String)
        case AllOther
    }
    
    private var notNamed: SequenceOf<SupplementalItemsMap.Group> {
        return supplementalItems.groups { (key, _) in
            key != UICollectionElementKindSectionHeader && key != UICollectionElementKindSectionFooter && key != ElementKindPlaceholder
        }
    }
    
    func count(#supplements: Supplement) -> Int {
        switch supplements {
        case .Header:
            return supplementalItems[UICollectionElementKindSectionHeader].count
        case .Footer:
            return supplementalItems[UICollectionElementKindSectionFooter].count
        case .Named(let kind):
            return supplementalItems[kind].count
        case .AllOther:
            return reduce(lazy(notNamed).map({
                $0.1.count
            }), 0, +)
        }
    }
    
    subscript(supplement: Supplement) -> SupplementalItemsMap.Sequence {
        switch supplement {
        case .Header:
            return supplementalItems.enumerate(forKey: UICollectionElementKindSectionHeader)
        case .Footer:
            return supplementalItems.enumerate(forKey: UICollectionElementKindSectionFooter)
        case .Named(let kind):
            return supplementalItems.enumerate(forKey: kind)
        case .AllOther:
            return MultimapSequence(notNamed)
        }
    }
    
    var placeholder: SupplementInfo? {
        return supplementalItems[ElementKindPlaceholder].first
    }
    
    mutating func addSupplementalItem(metrics: SupplementaryMetrics) {
        let info = SupplementInfo(metrics: metrics)
        if metrics.kind == ElementKindPlaceholder {
            supplementalItems.update(CollectionOfOne(info), forKey: ElementKindPlaceholder)
        } else {
            supplementalItems.append(info, forKey: metrics.kind)
        }
    }
    
    mutating func addItems(count: Int) {
        items += Repeat(count: count, repeatedValue: ItemInfo())
    }
    
}

extension SectionInfo {
    
    typealias MeasureSupplement = (kind: String, index: Int, fittingSize: CGSize) -> CGSize
    typealias MeasureItem = (index: Int, fittingSize: CGSize) -> CGSize
    
    mutating func layout(rect viewport: CGRect, inout nextStart: CGPoint, measureSupplement: MeasureSupplement, measureItem: MeasureItem? = nil) {
        rows.removeAll(keepCapacity: true)
        
        let numberOfItems = items.count
        let numberOfColumns = metrics.numberOfColumns ?? 1
        
        var layoutRect = viewport
        layoutRect.size.height = CGFloat.infinity
        
        // First, lay out headers
        let headerBeginY = layoutRect.minY
        supplementalItems.updateMapWithIndex(groupForKey: UICollectionElementKindSectionHeader) { (headerIndex, var headerInfo) -> SupplementInfo in
            // skip headers if there are no items and the header isn't a global header
            if numberOfItems == 0 && !headerInfo.metrics.isVisibleWhileShowingPlaceholder { return headerInfo }
            
            // skip headers that are hidden
            if (headerInfo.metrics.isHidden) { return headerInfo }
            
            var length = CGFloat(0)
            switch (headerInfo.measurement, headerInfo.metrics.measurement) {
            case (.None, .None):
                return headerInfo
            case (_, .Static(let value)):
                headerInfo.measurement = .Static(value)
                length = value
            case (.None, .Estimate(let estimate)):
                // This header needs to be measured!
                let fittingSize = CGSize(width: viewport.width, height: UILayoutFittingExpandedSize.height)
                headerInfo.frame = CGRect(origin: CGPoint.zeroPoint, size: fittingSize)
                length = measureSupplement(kind: UICollectionElementKindSectionHeader, index: headerIndex, fittingSize: fittingSize).height
                headerInfo.measurement = .Static(length)
            default: break
            }
            
            headerInfo.frame = layoutRect.divide(length)

            return headerInfo
        }
        
        headersRect = CGRect(x: viewport.minX, y: headerBeginY, width: viewport.width, height: layoutRect.minY - headerBeginY)
        
        switch (numberOfItems, placeholder) {
        case (_, .None) where numberOfItems != 0:
            // Lay out items and footers only if there actually ARE items.
            var itemsLayoutRect = layoutRect.rectByInsetting(insets: metrics.groupPadding)
            
            let columnWidth = itemsLayoutRect.width / CGFloat(numberOfColumns)
            let divideFrom = metrics.layoutSlicingEdge
            
            rows.reserveCapacity(1 + items.count / numberOfColumns)
            
            for range in take(items.startIndex..<items.endIndex, eachSlice: numberOfColumns) {
                let original = items[range]
                
                // take a measurement pass through all items
                let reviewPass = original.map { (var item) -> ItemInfo in
                    switch (item.measurement, self.metrics.measurement) {
                    case (.None, .None): break
                    case (_, .Static(let value)):
                        item.measurement = .Static(value)
                    case (.None, .Estimate(let estimate)):
                        item.measurement = .Estimate(estimate)
                        item.frame = CGRect(origin: itemsLayoutRect.origin, size: CGSize(width: columnWidth, height: UILayoutFittingExpandedSize.height))
                    default: break
                    }
                    return item
                }
                
                items[range] = reviewPass
                
                let measurePass = reviewPass.mapWithIndex { (sliceIdx, var item) -> ItemInfo in
                    switch (item.measurement, measureItem) {
                    case (.Estimate(let estimate), .Some(let measure)):
                        let idx = range.startIndex.advancedBy(sliceIdx)
                        let measured = measure(index: idx, fittingSize: item.frame.size)
                        item.measurement = .Static(measured.height)
                    default: break
                    }
                    return item
                }
                
                // Don't update the items list with this purposefully
                
                let rowHeight = maxElement(lazy(measurePass).map { $0.measurement.lengthValue })
                let rowRect = itemsLayoutRect.divide(rowHeight)
                var rowLayoutRect = rowRect
                
                let finalPass = measurePass.map { (var item) -> ItemInfo in
                    item.frame = rowLayoutRect.divide(columnWidth, edge: divideFrom)
                    return item
                }
                
                let row = RowInfo(items: finalPass, frame: rowRect)
                rows.append(RowInfo(items: finalPass, frame: rowRect))
                
                items[range] = finalPass
            }
            
            let itemsEndRect = itemsLayoutRect.divide(metrics.groupPadding.bottom)
            let itemsHeight = itemsLayoutRect.minY + metrics.groupPadding.bottom - layoutRect.minY
            let itemsRect = layoutRect.divide(itemsHeight)
            
            // Lay out footers as well
            supplementalItems.updateMapWithIndex(groupForKey: UICollectionElementKindSectionFooter) { (footerInfex, var footerInfo) -> SupplementInfo in
                // skip hidden footers
                if (footerInfo.metrics.isHidden) { return footerInfo }
                
                // Temporary: give this full measurement as well
                var height = CGFloat(0)
                
                switch footerInfo.metrics.measurement {
                case .Static(let value):
                    height = value
                default:
                    return footerInfo
                }
                
                footerInfo.frame = layoutRect.divide(height)
                
                return footerInfo
            }
        case (_, .Some(var placeholder)) where numberOfItems == 0:
            // Height of the placeholder is equal to the height of the collection view minus the height of the headers
            let frame = layoutRect.rectByIntersecting(viewport)
            placeholder.measurement = .Static(frame.height)
            placeholder.frame = frame
            _ = layoutRect.divide(frame.height)
        default: break
        }
        
        frame = CGRect(x: viewport.minX, y: viewport.minY, width: viewport.width, height: layoutRect.minY - viewport.minY)
        nextStart = CGPoint(x: frame.minX, y: frame.maxY)
    }
    
}

extension SectionInfo {
    
    mutating func remeasureItem(atIndex index: Int, function: MeasureItem) {
        var item = items[index]
        
        let fittingSize = CGSize(width: item.frame.width, height: UILayoutFittingExpandedSize.height)
        item.frame.size = function(index: index, fittingSize: fittingSize)
        
        items[index] = item
    }
    
}

// MARK: Printing

extension ItemInfo: DebugPrintable {
    
    var debugDescription: String {
        return "{Item}: \(NSStringFromCGRect(frame))"
    }
    
}

extension SupplementInfo: DebugPrintable {
    
    var debugDescription: String {
        return "{Supplement}: \(NSStringFromCGRect(frame))"
    }
    
}

extension RowInfo: DebugPrintable {
    
    var debugDescription: String {
        var ret = "{Section}: \(NSStringFromCGRect(frame))"
        if !isEmpty(items) {
            let desc = join("\n        ", items.map { $0.debugDescription })
            ret += "\n    items = [\n        \(desc)\n    ]"
        }
        return ret
    }
    
}

extension SectionInfo: DebugPrintable {
    
    var debugDescription: String {
        var ret = "{Section}: \(NSStringFromCGRect(frame))"
        
        if !rows.isEmpty {
            let desc = join("\n        ", rows.map { $0.debugDescription })
            ret += "\n    rows = [\n        %@\n    ]"
        }
        
        if !supplementalItems.isEmpty {
            let desc = join("\n", map(supplementalItems.groups()) {
                let desc = join("\n", map($1) { "            \($0.debugDescription)" })
                return "        \($0) = [\n\(desc)         ]\n"
            })
            ret += "\n    supplements = [\n\(desc)\n     ]"
        }
        
        return ret
    }
    
}
