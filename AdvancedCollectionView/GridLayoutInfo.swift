//
//  GridLayoutInfo.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/22/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

struct GridLayoutCacheKey<Kind: RawRepresentable where Kind.RawValue == String> {
    let indexPath: NSIndexPath
    let kind: Kind
    
    init(indexPath: NSIndexPath, kind: Kind) {
        self.indexPath = indexPath
        self.kind = kind
    }
    
    init!(indexPath: NSIndexPath, representedElementKind: String) {
        if let kind = Kind(rawValue: representedElementKind) {
            self.init(indexPath: indexPath, kind: kind)
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

struct SupplementInfo {
    let metrics: SupplementaryMetrics
    var frame = CGRect.zeroRect
}

struct ItemInfo {
    var frame = CGRect.zeroRect
    var measuredHeight = ItemMeasurement.None
    var columnIndex = 0
}

struct RowInfo {
    let items = [ItemInfo]()
    var frame = CGRect.zeroRect
}

extension SectionMetrics {
    
    var groupPadding: UIEdgeInsets? {
        return padding?.without(.Left | .Right)
    }
    
    var itemPadding: UIEdgeInsets? {
        return padding?.without(.Top | .Bottom)
    }
    
    /// Extension-safe
    private static let layoutDirection: UIUserInterfaceLayoutDirection = {
        let direction = NSParagraphStyle.defaultWritingDirectionForLanguage(nil)
        switch NSParagraphStyle.defaultWritingDirectionForLanguage(nil) {
        case .LeftToRight:
            return .LeftToRight
        case .RightToLeft:
            return .RightToLeft
        case .Natural:
            if let localization = NSBundle.mainBundle().preferredLocalizations.first as? String {
                return NSLocale.characterDirectionForLanguage(localization) == .RightToLeft ? .RightToLeft : .LeftToRight
            }
            return .LeftToRight
        }
        }()
    
    var effectiveLayoutSlicingEdge: CGRectEdge {
        let layout = itemLayout ?? .Natural
        switch layout {
        case .Natural:
            return SectionMetrics.layoutDirection == .LeftToRight ? .MinXEdge : .MaxXEdge
        case .NaturalReverse:
            return SectionMetrics.layoutDirection == .RightToLeft ? .MinXEdge : .MaxXEdge
        case .LeadingToTrailing:
            return .MinXEdge
        case .TrailingToLeading:
            return .MaxXEdge
        }
    }
    
}

enum Supplement {
    case Header
    case Other(String)
    case AllOther
}

struct SectionInfo {
    
    typealias Attributes = GridLayoutAttributes
    
    let metrics: SectionMetrics
    var frame = CGRect.zeroRect
    var pinnableAttributes = [Attributes]()
    
    private var rows = [RowInfo]()
    var items = [ItemInfo]()
    
    typealias SupplementalItemsMap = Multimap<String, SupplementInfo>
    private(set) var supplementalItems = SupplementalItemsMap()
    
    private var nonHeaders: SequenceOf<SupplementalItemsMap.Group> {
        return supplementalItems.groups { (key, _) in
            key != UICollectionElementKindSectionHeader && key != ElementKindPlaceholder
        }
    }
    
    func count(#supplements: Supplement) -> Int {
        switch supplements {
        case .Header:
            return supplementalItems[UICollectionElementKindSectionHeader].count
        case .Other(let kind):
            return supplementalItems[kind].count
        case .AllOther:
            return reduce(lazy(nonHeaders).map({
                $0.1.count
            }), 0, +)
        }
    }
    
    func enumerate(#supplements: Supplement) -> SupplementalItemsMap.Generator {
        switch supplements {
        case .Header:
            return supplementalItems.enumerate(forKey: UICollectionElementKindSectionHeader)
        case .Other(let kind):
            return supplementalItems.enumerate(forKey: kind)
        case .AllOther:
            return MultimapGenerator(nonHeaders)
        }
    }
    
    subscript(supplement: Supplement, index: Int) -> SupplementInfo? {
        switch supplement.0 {
        case .Header:
            return supplementalItems[UICollectionElementKindSectionHeader, index]
        case .Other(let kind):
            return supplementalItems[kind, index]
        case .AllOther:
            return nil
        }
    }
    
    var placeholder: SupplementInfo? {
        return supplementalItems[ElementKindPlaceholder].first
    }
    
    typealias MeasureSupplement = (kind: String, index: Int, fittingSize: CGSize) -> CGSize
    typealias MeasureItem = (index: Int, fittingSize: CGSize) -> CGSize
    
    mutating func layout(rect viewport: CGRect, measureSupplement: MeasureSupplement, measureItem: MeasureItem? = nil) -> CGPoint {
        return CGPoint.zeroPoint
    }
    
}
