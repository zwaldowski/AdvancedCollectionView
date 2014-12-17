//
//  Metrics.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

public let DefaultRowHeight = CGFloat(44)
public let ElementKindPlaceholder = "placeholder"

public enum Section: Hashable {
    case Index(Int)
    case Global
    
    public var hashValue: Int {
        switch self {
        case .Index(let a): return a.hashValue
        default: return Int.max.hashValue
        }
    }
}

public func ==(lhs: Section, rhs: Section) -> Bool {
    switch (lhs, rhs) {
    case (.Index(let a), .Index(let b)):
        return a == b
    case (.Global, .Global):
        return true
    default:
        return false
    }
}

public enum LayoutOrder {
    case LeadingToTrailing
    case TrailingToLeading
    case Natural
    case NaturalReverse
}

public struct SeparatorOptions: RawOptionSetType {
    public init(rawValue value: UInt) { self.value = value }
    public init(nilLiteral: ()) { self.init(rawValue: 0) }
    
    private var value: UInt = 0
    public var rawValue: UInt { return self.value }
    
    public static var allZeros: SeparatorOptions { return nil }
    public static var BeforeSections: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 0) }
    public static var Supplements: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 1) }
    public static var Rows: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 2) }
    public static var Columns: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 3) }
    public static var AfterSections: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 4) }
    public static var AfterLastSection: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 5) }
}

public enum ItemMeasurement {
    case None
    case Value(CGFloat)
    case Estimated(CGFloat)
}

public struct SupplementaryMetrics {
    
    /// The class to use when dequeuing an instance of this supplementary view
    var viewType: UICollectionReusableView.Type = UICollectionReusableView.self

    /// The kind of supplementary view these metrics describe
    public let kind: String
    /// Should this supplementary view be displayed while the placeholder is visible?
    public var isVisibleWhileShowingPlaceholder = false
    /// Should this supplementary view be pinned to the edges of the view when
    /// scrolling? Only valid for headers and footers.
    public var shouldPin = false
    /// The size of the supplementary view relative to the layout.
    public var itemMeasurement = ItemMeasurement.None
    /// Should the supplementary view be hidden?
    public var isHidden = false
    /// Use top & bottom padding to adjust spacing of header & footer elements.
    /// Not all headers & footers adhere to padding. Default @c UIEdgeInsetsZero
    /// which is interpretted by supplementary items to be their default values.
    public var isPadding = UIEdgeInsetsZero
    /// How is this affected by other coinciding views?
    public var zIndex = GridLayout.ZIndex.Supplement.rawValue
    /// Optional reuse identifier. If not specified, it will be inferred from the
    /// class of the supplementary view.
    public var reuseIdentifier: String {
        set { __reuseIdentifier = newValue }
        get {
            if let value = __reuseIdentifier {
                return value
            }
            return NSStringFromClass(viewType)
        }
    }
    private var __reuseIdentifier: String? = nil
    
    /// The background color that should be used for this element. On an item,
    /// if not set, this will be inherited from the section.
    public var backgroundColor: UIColor? = nil
    /// The background color shown when this element is selected. On an item, if
    /// not set, this will be inherited from the section. Use the clear color
    /// to override a selection color from the section.
    public var selectedBackgroundColor: UIColor? = nil
    /// The preferred tint color used for this element. On an item, if not set,
    /// not set, it will be inherited from the section.
    public var tintColor: UIColor? = nil
    /// The preferred tint color used for this element when selected. On an
    /// item, if not set, it will be inherited from the section. Use the clear
    /// color to override the inherited color.
    public var selectedTintColor: UIColor? = nil
    
    var configureView: ((view: UICollectionReusableView, dataSource: DataSource, indexPath: NSIndexPath) -> ())?
    
    /// Add a configuration block to the supplementary view. This does not clear existing configuration blocks.
    public mutating func configure<V: UICollectionReusableView, DS: DataSource>(closure: (view: V!, dataSource: DS!, indexPath: NSIndexPath) -> ()) {
        viewType = V.self
        
        if let old = configureView {
            // chain the old with the new
            configureView = {
                old(view: $0, dataSource: $1, indexPath: $2)
                closure(view: $0 as? V, dataSource: $1 as? DS, indexPath: $2)
            }
        } else {
            configureView = {
                closure(view: $0 as? V, dataSource: $1 as? DS, indexPath: $2)
            }
        }
    }
    
}

public struct SectionMetrics {
    
    public init() { }
    
    public init(defaultMetrics: ()) {
        itemMeasurement = .Value(DefaultRowHeight)
        numberOfColumns = 1
        separators = SeparatorOptions.Supplements | SeparatorOptions.Rows | SeparatorOptions.Columns | SeparatorOptions.AfterSections
    }
    
    /// The size of each row in the section.
    public var itemMeasurement: ItemMeasurement? = nil
    /// Number of columns in this section. Sections will inherit a default of
    /// 1 from the data source.
    public var numberOfColumns: Int? = nil
    /// Padding around the cells for this section. The top & bottom padding
    /// will be applied between the headers & footers and the cells. The left &
    /// right padding will be applied between the view edges and the cells.
    public var padding: UIEdgeInsets? = nil
    /// How the cells should be laid out when there are multiple columns.
    public var itemLayout: LayoutOrder? = nil
    
    /// Determines where, if any, separators are drawn.
    public var separators: SeparatorOptions? = nil
    /// Insets for the separators drawn between rows (left & right) and
    /// columns (top & bottom).
    public var separatorInsets: UIEdgeInsets? = nil
    
    private var setSeparatorColor = false
    private var setBackgroundColor = false
    private var setSelectedBackgroundColor = false
    private var setTintColor = false
    private var setSelectedTintColor = false
    
    /// The color to use when drawing row, column, and section separators.
    public var separatorColor: UIColor? = nil {
        didSet { setSeparatorColor = true }
    }
    /// The background color that should be used for this element. On an item,
    /// if not set, this will be inherited from the section.
    public var backgroundColor: UIColor? = nil {
        didSet { setBackgroundColor = true }
    }
    /// The background color shown when this element is selected. On an item, if
    /// not set, this will be inherited from the section. Use the clear color
    /// to override a selection color from the section.
    public var selectedBackgroundColor: UIColor? = nil {
        didSet { setSelectedBackgroundColor = true }
    }
    /// The preferred tint color used for this element. On an item, if not set,
    /// not set, it will be inherited from the section.
    public var tintColor: UIColor? = nil {
        didSet { setTintColor = true }
    }
    /// The preferred tint color used for this element when selected. On an
    /// item, if not set, it will be inherited from the section. Use the clear
    /// color to override the inherited color.
    public var selectedTintColor: UIColor? = nil {
        didSet { setSelectedTintColor = true }
    }
    
    var hasPlaceholder = false
    
    /// Supplementary view metrics for this section
    public var supplementaryViews = [SupplementaryMetrics]()
    
    public mutating func addSupplement(supplement: SupplementaryMetrics) {
        supplementaryViews.append(supplement)
    }
    
    public mutating func apply(metrics other: SectionMetrics) {
        if let otherMeasurement = other.itemMeasurement { itemMeasurement = otherMeasurement }
        if let otherColumns = other.numberOfColumns { numberOfColumns = otherColumns }
        if let otherPadding = other.padding { padding = otherPadding }
        if let otherOrder = other.itemLayout { itemLayout = otherOrder }
        if let otherSeparators = other.separators { separators = otherSeparators }
        if let otherInsets = other.separatorInsets { separatorInsets = otherInsets }
        if other.setSeparatorColor { separatorColor = other.separatorColor }
        if other.setBackgroundColor { backgroundColor = other.backgroundColor }
        if other.setSelectedBackgroundColor { selectedBackgroundColor = other.selectedBackgroundColor }
        if other.setTintColor { tintColor = other.tintColor }
        if other.setSelectedTintColor { selectedTintColor = other.selectedTintColor }
        supplementaryViews.extend(other.supplementaryViews)
        hasPlaceholder |= other.hasPlaceholder
    }
    
}
