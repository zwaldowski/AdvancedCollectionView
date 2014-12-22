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

private struct CacheKey {
    let indexPath: NSIndexPath
    let kind: String
}

private func ==(lhs: CacheKey, rhs: CacheKey) -> Bool {
    return lhs.kind != rhs.kind ||
        lhs.indexPath === rhs.indexPath ||
        lhs.indexPath == rhs.indexPath
}

extension CacheKey: Equatable {}

extension CacheKey: Hashable {
    
    var hashValue: Int {
        return 31 &* indexPath.hashValue &+ kind.hashValue
    }
    
}

extension CacheKey: DebugPrintable {
    
    var debugDescription: String {
        let commaSeparated = join(", ", map(indexPath) { String($0) })
        return "\(kind)@{\(commaSeparated)}"
    }
    
}

// MARK: -

private struct SupplementInfo {
    let metrics: SupplementaryMetrics
    var frame = CGRect.zeroRect
}

private struct ItemInfo {
    var frame = CGRect.zeroRect
    var measuredHeight = ItemMeasurement.None
    var isDragging = false
    var columnIndex = 0
}

private struct RowInfo {
    let items = [ItemInfo]()
    var frame = CGRect.zeroRect
}

private extension SectionMetrics {
    
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

private struct SectionInfo {
    let metrics: SectionMetrics
    var frame = CGRect.zeroRect
    
    var phantomCell: (index: Int, size: CGSize)? = nil
    
    var pinnableAttributes = [GridLayoutAttributes]()
    
    private var rows = [RowInfo]()
    private var items = [ItemInfo]()
    
    private typealias SupplementalItemsMap = Multimap<String, SupplementInfo>
    private var supplementalItems = SupplementalItemsMap()
    
    enum Supplement {
        case Header
        case Other(String)
        case AllOther
    }
    
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

// MARK: -

public class GridLayout: UICollectionViewLayout {
    
    public let DefaultRowHeight = CGFloat(44)
    public let ElementKindPlaceholder = "placeholder"
    public enum ZIndex: Int {
        case Item = 1
        case Supplement = 100
        case Decoration = 1000
        case SupplementPinned = 10000
    }
    
    // MARK:
    
    var isEditing: Bool = false {
        didSet {
            
        }
    }
    
    // MARK: Public methods
    
    public func invalidateLayout(forItemAtIndexPath indexPath: NSIndexPath) {
        // TODO:
    }
    
    public func invalidateLayoutForGlobalSection() {
        // TODO:
    }
    

    private var contentSizeAdjustment = CGSize.zeroSize
    private var contentOffsetAdjustment = CGPoint.zeroPoint
    
    public override func prepareLayout() {
        super.prepareLayout()
        
        contentSizeAdjustment = CGSize.zeroSize
        contentOffsetAdjustment = CGPoint.zeroPoint
        
        let bounds = collectionView.map { $0.bounds } ?? CGRect.zeroRect
        
        if !bounds.isEmpty {
            //[rbx _fetchItemsInfoForRect:rdx]
        }
    }
    
}
