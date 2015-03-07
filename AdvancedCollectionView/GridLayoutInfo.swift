//
//  GridLayoutInfo.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/22/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

enum ElementKey: Hashable {
    
    typealias IndexPathKind = (NSIndexPath, String)
    
    case Cell(NSIndexPath)
    case Supplement(IndexPathKind)
    case Decoration(IndexPathKind)
    
    init(_ indexPath: NSIndexPath) {
        self = .Cell(indexPath)
    }
    
    init(supplement kind: String, _ indexPath: NSIndexPath) {
        self = .Supplement(indexPath, kind)
    }
    
    init(decoration kind: String, _ indexPath: NSIndexPath) {
        self = .Decoration(indexPath, kind)
    }
    
    var indexPath: NSIndexPath {
        switch self {
        case .Cell(let indexPath):
            return indexPath
        case .Supplement(let kind):
            return kind.0
        case .Decoration(let kind):
            return kind.0
        }
    }
    
    var correspondingItem: ElementKey {
        return ElementKey(indexPath)
    }
    
    func correspondingSupplement(kind: String) -> ElementKey {
        return ElementKey(supplement: kind, indexPath)
    }
    
    var components: (Section, Int) {
        let ip = indexPath
        if ip.length == 1 {
            return (.Global, ip[0])
        }
        return (.Index(ip[0]), ip[1])
    }
    
}

private func ==(lhs: ElementKey.IndexPathKind, rhs: ElementKey.IndexPathKind) -> Bool {
    return (lhs.0 === rhs.0 || lhs.0 == rhs.0) && lhs.1 == rhs.1
}

func ==(lhs: ElementKey, rhs: ElementKey) -> Bool {
    switch (lhs, rhs) {
    case (.Cell(let lIndexPath), .Cell(let rIndexPath)):
        return lIndexPath == rIndexPath
    case (.Supplement(let lhsKey), .Supplement(let rhsKey)):
        return lhsKey == rhsKey
    case (.Decoration(let lhsKey), .Decoration(let rhsKey)):
        return lhsKey == rhsKey
    default:
        return false
    }
}

extension ElementKey: Hashable {
    
    var hashValue: Int {
        var build = SimpleHash(prime: 37)
        switch self {
        case .Cell:
            build.append(UICollectionElementCategory.Cell)
        case .Supplement(let kind):
            build.append(UICollectionElementCategory.SupplementaryView)
            build.append(kind.1)
        case .Decoration(let kind):
            build.append(UICollectionElementCategory.DecorationView)
            build.append(kind.1)
        default: break
        }
        build.append(indexPath)
        return build.result
    }
    
}

extension ElementKey: Printable, DebugPrintable {
    
    var description: String {
        func describeIndexPath(indexPath: NSIndexPath) -> String {
            return join(", ", map(indexPath) { String($0) })
        }
        
        func describeKind(kind: IndexPathKind) -> String {
            return "\(kind.1)@\(describeIndexPath(kind.0))"
        }
        
        switch self {
        case .Cell(let indexPath):
            return describeIndexPath(indexPath)
        case .Supplement(let kind):
            return describeKind(kind)
        case .Decoration(let kind):
            return describeKind(kind)
        }
    }
    
    var debugDescription: String {
        return description
    }
    
}

// MARK: -

private extension SectionMetrics {
    
    func itemPadding(#rows: HalfOpenInterval<Int>, columns: HalfOpenInterval<Int>) -> UIEdgeInsets {
        if var insets = padding {
            if rows.start != 0 {
                insets.top = 0
            }
            
            if !rows.isEmpty {
                insets.bottom = 0
            }
            
            if columns.start > 0 {
                insets.left = 0
            }
            
            if !columns.isEmpty {
                insets.right = 0
            }
            
            return insets
        }
        return UIEdgeInsets()
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
    let measurement: ElementLength
    let frame: CGRect
    
    private init(metrics: SupplementaryMetrics, measurement: ElementLength? = nil, frame: CGRect = CGRect()) {
        self.metrics = metrics
        self.measurement = measurement ?? metrics.measurement!
        self.frame = frame
    }
    
}

struct ItemInfo {
    
    let measurement: ElementLength
    let padding: UIEdgeInsets
    let frame: CGRect
    
    private init(measurement: ElementLength, padding: UIEdgeInsets = UIEdgeInsets(), frame: CGRect = CGRect()) {
        self.measurement = measurement
        self.padding = padding
        self.frame = frame
    }
    
    
}

struct RowInfo {
    
    let items: Slice<ItemInfo>
    let frame: CGRect
    
    private init(items: Slice<ItemInfo>, frame: CGRect) {
        self.items = items
        self.frame = frame
    }
    
}

struct SectionInfo {
    
    let metrics: SectionMetrics
    private(set) var items = [ItemInfo]()
    private(set) var rows = [RowInfo]() // ephemeral, only full once laid out
    private(set) var supplementalItems = Multimap<String, SupplementInfo>()
    private(set) var frame = CGRect()
    
    private var headersRect = CGRect()
    private var itemsRect = CGRect()
    private var footersRect = CGRect()
    
    var contentRect: CGRect {
        return frame.rectByInsetting(insets: UIEdgeInsetsMake(0, 0, metrics.margin ?? 0, 0))
    }
    
    init(metrics: SectionMetrics) {
        self.metrics = metrics
    }
    
//    init(metrics: SectionMetrics, supplements: [Supplement]
    
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
        supplementalItems.append(info, forKey: metrics.kind)
    }
    
    mutating func addPlaceholder() {
        let metrics = SupplementaryMetrics(kind: SupplementKind.Placeholder)
        let info = SupplementInfo(metrics: metrics, measurement: .Remainder)
        placeholder = info
    }
    
    mutating func addItems(count: Int) {
        let item = ItemInfo(measurement: metrics.measurement!)
        items += Repeat(count: count, repeatedValue: item)
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
        supplementalItems.updateMapWithIndex(groupForKey: headerKey) { (headerIndex, headerInfo) in
            // skip headers if there are no items and the header isn't a global header
            if numberOfItems == 0 && !headerInfo.metrics.isVisibleWhileShowingPlaceholder { return headerInfo }
            
            // skip headers that are hidden
            if headerInfo.metrics.isHidden { return headerInfo }
            
            var measurement: ElementLength!
            
            switch (headerInfo.measurement, headerInfo.metrics.measurement) {
            case (_, .Some(let value)):
                measurement = value
            case (.Estimate(let estimate), _):
                // This header needs to be measured!
                let frame = CGRect(origin: layoutRect.origin, size: CGSize(width: viewport.width, height: estimate))
                let measure = measureSupplement(kind: headerKey, index: headerIndex, measuringFrame: frame)
                measurement = .Static(measure.height)
            case (let value, _):
                measurement = value
            }
            
            let frame = layoutRect.divide(measurement.lengthValue)
            return SupplementInfo(metrics: headerInfo.metrics, measurement: measurement, frame: frame)
        }
        
        headersRect = CGRect(x: viewport.minX, y: headerBeginY, width: viewport.width, height: layoutRect.minY - headerBeginY)
        
        switch (numberOfItems, placeholder) {
        case (0, .Some(var info)):
            itemsRect = CGRect()
            footersRect = CGRect()
            
            // Height of the placeholder is equal to the height of the collection view minus the height of the headers
            let frame = layoutRect.rectByIntersecting(viewport)
            placeholder = SupplementInfo(metrics: info.metrics, measurement: .Static(frame.height), frame: frame)
            
            _ = layoutRect.divide(frame.height)
        case (_, .None) where numberOfItems != 0:
            // Lay out items and footers only if there actually ARE items.
            let itemsBeginY = layoutRect.minY
            
            let columnsPointsRatio = CGFloat(numberOfColumns)
            let maxWidth = metrics.padding.map { layoutRect.width - $0.left - $0.right } ?? layoutRect.width
            let numberOfRows =  Int(ceil(CGFloat(items.count) / columnsPointsRatio))

            let columnWidth = maxWidth / columnsPointsRatio
            let divideFrom = metrics.layoutSlicingEdge
            let sectionMeasurement = metrics.measurement
            
            rows.reserveCapacity(numberOfRows + 1)
            
            for range in take(items.startIndex..<items.endIndex, eachSlice: numberOfColumns) {
                let original = items[range]
                
                // take a measurement pass through all items
                let measurePass = original.mapWithIndex { (columnIndex, item) -> ItemInfo in
                    let rowIndex = self.rows.count
                    let padding = self.metrics.itemPadding(rows: rowIndex..<numberOfRows, columns: columnIndex..<numberOfColumns)
                    let measurement = { () -> ElementLength in
                        switch (item.measurement, sectionMeasurement, measureItem) {
                        case (_, .Some(.Static(let value)), _):
                            return .Static(value + padding.top + padding.bottom)
                        case (.Estimate(let estimate), _, .Some(let measure)):
                            let idx = range.startIndex.advancedBy(columnIndex)
                            let width = columnWidth + padding.left + padding.right
                            let height = estimate + padding.top + padding.bottom
                            let frame = CGRect(origin: layoutRect.origin, size: CGSize(width: width, height: height))
                            let measured = measure(index: idx, measuringFrame: frame)
                            return .Static(measured.height)
                        case (let passthrough, _, _):
                            return passthrough
                        }
                    }()
                    
                    return ItemInfo(measurement: measurement, padding: padding, frame: item.frame)
                }
                
                let rowHeight = maxElement(lazy(measurePass).map { $0.measurement.lengthValue })
                let rowRect = layoutRect.divide(rowHeight)
                var rowLayoutRect = rowRect
                
                items[range] = measurePass.map {
                    let frame = rowLayoutRect.divide(columnWidth, fromEdge: divideFrom)
                    return ItemInfo(measurement: $0.measurement, padding: $0.padding, frame: frame)
                }
                
                rows.append(RowInfo(items: items[range], frame: rowRect))
            }
            
            itemsRect = CGRect(x: viewport.minX, y: itemsBeginY, width: viewport.width, height: layoutRect.minY - itemsBeginY)
            
            // Lay out footers as well
            let footerBeginY = layoutRect.minY
            let headerKey = SupplementKind.Header.rawValue
            supplementalItems.updateMapWithIndex(groupForKey: SupplementKind.Footer.rawValue) { (footerInfex, footerInfo) in
                // skip hidden footers
                if (footerInfo.metrics.isHidden) { return footerInfo }
                
                // Temporary: give this full measurement as well
                var height = CGFloat(0)
                
                switch footerInfo.metrics.measurement {
                case .Some(.Static(let value)):
                    height = value
                default:
                    return footerInfo
                }
                
                let frame = layoutRect.divide(height)
                return SupplementInfo(metrics: footerInfo.metrics, measurement: footerInfo.measurement, frame: frame)
            }
            footersRect = CGRect(x: viewport.minX, y: footerBeginY, width: viewport.width, height: layoutRect.minY - footerBeginY)
        default: break
        }
        
        // This is now the beginning of the section gap for the next section
        if let bottom = metrics.margin {
            _ = layoutRect.divide(bottom)
        }
        
        frame = CGRect(x: viewport.minX, y: viewport.minY, width: viewport.width, height: layoutRect.minY - viewport.minY)
        nextStart = CGPoint(x: frame.minX, y: frame.maxY)
    }
    
}

extension SectionInfo {
    
    mutating func remeasureItem(atIndex index: Int, function: MeasureItem) {
        let original = items[index]
        
        var newFrame = CGRect(origin: original.frame.origin, size: CGSize(width: original.frame.width, height: UILayoutFittingExpandedSize.height))
        newFrame.size = function(index: index, measuringFrame: newFrame)
        let newMeasurement = ElementLength.Static(newFrame.height)
        
        items[index] = ItemInfo(measurement: newMeasurement, padding: original.padding, frame: newFrame)
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
