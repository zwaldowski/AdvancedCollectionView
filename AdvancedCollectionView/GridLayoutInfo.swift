//
//  GridLayoutInfo.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/22/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

struct GridCacheKey {
    let kind: String
    let indexPath: NSIndexPath
    
}

func ==(lhs: GridCacheKey, rhs: GridCacheKey) -> Bool {
    return lhs.indexPath === rhs.indexPath || lhs.kind == rhs.kind || lhs.indexPath == rhs.indexPath
}

extension GridCacheKey: Hashable {
    
    var hashValue: Int {
        return 31 &* indexPath.hashValue &+ kind.hashValue
    }
    
}

extension GridCacheKey: DebugPrintable {
    
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
    
    let metrics: SectionMetrics

    init(metrics: SectionMetrics) {
        self.metrics = metrics
    }
    
    private var items = [ItemInfo]()
    private(set) var rows = [RowInfo]() // ephemeral
    private var supplementalItems = Multimap<String, SupplementInfo>()
    
    private(set) var frame = CGRect.zeroRect
    private(set) var headersRect = CGRect.zeroRect
    
}

// MARK: Attributes access

extension SectionInfo {
    
    enum SupplementIndex {
        case Header
        case Footer
        case Named(String)
        case AllOther
    }
    
    private var notNamed: SequenceOf<(String, [SupplementInfo]) > {
        return supplementalItems.groups { (key, _) in
            key != SupplementKind.Header.rawValue && key != SupplementKind.Footer.rawValue
        }
    }
    
    func count(#supplements: SupplementIndex) -> Int {
        switch supplements {
        case .Header:
            return supplementalItems[SupplementKind.Header.rawValue].count
        case .Footer:
            return supplementalItems[SupplementKind.Footer.rawValue].count
        case .Named(let kind):
            return supplementalItems[kind].count
        case .AllOther:
            return reduce(lazy(notNamed).map({
                $0.1.count
            }), 0, +)
        }
    }
    
    subscript(supplement: SupplementIndex) -> SequenceOf<(String, Int, SupplementInfo)> {
        switch supplement {
        case .Header:
            return SequenceOf(supplementalItems.enumerate(forKey: SupplementKind.Header.rawValue))
        case .Footer:
            return SequenceOf(supplementalItems.enumerate(forKey: SupplementKind.Footer.rawValue))
        case .Named(let kind):
            return SequenceOf(supplementalItems.enumerate(forKey: kind))
        case .AllOther:
            return SequenceOf { MultimapEnumerateGenerator(self.notNamed) }
        }
    }
    
    var placeholder: SupplementInfo? {
        get {
            return supplementalItems[SupplementKind.Placeholder.rawValue].first
        }
        set {
            if let info = newValue {
                supplementalItems.update(CollectionOfOne(info), forKey: SupplementKind.Placeholder.rawValue)
            } else {
                supplementalItems.remove(valuesForKey: SupplementKind.Placeholder.rawValue)
            }
        }
    }
    
    mutating func addSupplementalItem(metrics: SupplementaryMetrics) {
        let info = SupplementInfo(metrics: metrics)
        if metrics.kind == SupplementKind.Placeholder.rawValue {
            placeholder = info
        } else {
            supplementalItems.append(info, forKey: metrics.kind)
        }
    }
    
    mutating func addItems(count: Int) {
        items += Repeat(count: count, repeatedValue: ItemInfo())
    }
    
    subscript (kind: String, supplementIndex: Int) -> SupplementInfo? {
        return supplementalItems[kind, supplementIndex]
    }
    
    var numberOfItems: Int {
        return items.count
    }
    
    subscript (itemIndex: Int) -> ItemInfo? {
        if itemIndex < items.endIndex {
            return items[itemIndex]
        }
        return nil
    }
    
}

extension SectionInfo {
    
    typealias MeasureItem = (index: Int, measuringFrame: CGRect) -> CGSize
    typealias MeasureSupplement = ( kind: String, index: Int, measuringFrame: CGRect) -> CGSize
    
    mutating func layout(rect viewport: CGRect, inout nextStart: CGPoint, measureSupplement: MeasureSupplement, measureItem: MeasureItem? = nil) {
        rows.removeAll(keepCapacity: true)
        
        let numberOfItems = items.count
        let numberOfColumns = metrics.numberOfColumns ?? 1
        
        var layoutRect = viewport
        layoutRect.size.height = CGFloat.infinity
        
        // First, lay out headers
        let headerBeginY = layoutRect.minY
        let headerKey = SupplementKind.Header.rawValue
        supplementalItems.updateMapWithIndex(groupForKey: headerKey) { (headerIndex, var headerInfo) -> SupplementInfo in
            // skip headers if there are no items and the header isn't a global header
            if numberOfItems == 0 && !headerInfo.metrics.isVisibleWhileShowingPlaceholder { return headerInfo }
            
            // skip headers that are hidden
            if (headerInfo.metrics.isHidden) { return headerInfo }
            
            var length = CGFloat(0)
            switch (headerInfo.measurement, headerInfo.metrics.measurement) {
            case (_, .Static(let value)):
                headerInfo.measurement = .Static(value)
                length = value
            case (.None, .Estimate(let estimate)):
                // This header needs to be measured!
                let frame = CGRect(origin: layoutRect.origin, size: CGSize(width: viewport.width, height: estimate))
                let measure = measureSupplement(kind: headerKey, index: headerIndex, measuringFrame: frame)
                headerInfo.measurement = .Static(measure.height)
                length = measure.height
            case (.Static(let value), _):
                length = value
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
                let measurePass = original.mapWithIndex { (sliceIdx, var item) -> ItemInfo in
                    switch (item.measurement, self.metrics.measurement, measureItem) {
                    case (_, .Static(let value), _):
                        item.measurement = .Static(value)
                    case (_, .Estimate(let estimate), .Some(let measure)):
                        let idx = range.startIndex.advancedBy(sliceIdx)
                        let frame = CGRect(origin: itemsLayoutRect.origin, size: CGSize(width: columnWidth, height: estimate))
                        let measured = measure(index: idx, measuringFrame: frame)
                        item.measurement = .Static(measured.height)
                    default: break
                    }
                    return item
                }
                
                let rowHeight = maxElement(lazy(measurePass).map { $0.measurement.lengthValue })
                let rowRect = itemsLayoutRect.divide(rowHeight)
                var rowLayoutRect = rowRect
                
                let finalPass = measurePass.map { (var item) -> ItemInfo in
                    item.frame = rowLayoutRect.divide(columnWidth, edge: divideFrom)
                    return item
                }
                
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
        case (_, .Some(var info)) where numberOfItems == 0:
            // Height of the placeholder is equal to the height of the collection view minus the height of the headers
            let frame = layoutRect.rectByIntersecting(viewport)
            info.measurement = .Static(frame.height)
            info.frame = frame
            placeholder = info
            
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
        item.frame.size = function(index: index, measuringFrame: CGRect(origin: item.frame.origin, size: fittingSize))
        
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
