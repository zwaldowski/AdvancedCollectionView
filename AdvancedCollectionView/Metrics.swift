//
//  Metrics.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

public enum LayoutOrder {
    case Natural
    case NaturalReverse
    case LeadingToTrailing
    case TrailingToLeading
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
}

public struct SupplementaryMetrics {
    
    /// The kind of supplementary view these metrics describe
    let kind: String
    /// The class to use when dequeuing an instance of this supplementary view
    public var viewType = UICollectionReusableView.self
    /// Should this supplementary view be displayed while the placeholder is visible?
    public var isVisibleWhileShowingPlaceholder = false
    /// Should this supplementary view be pinned to the edges of the view when
    /// scrolling? Only valid for headers and footers.
    public var shouldPin = false
    /// The size of the supplementary view relative to the layout.
    public var measurement: ElementLength? = nil
    /// Should the supplementary view be hidden?
    public var isHidden = false
    /// Use top & bottom padding to adjust spacing of header & footer elements.
    /// Not all headers & footers adhere to padding. Default @c UIEdgeInsets()
    /// which is interpretted by supplementary items to be their default values.
    public var padding = UIEdgeInsets()
    /// How is this affected by other coinciding views?
    public var zIndex = GridLayout.ZIndex.Supplement.rawValue
    /// Optional reuse identifier. If not specified, it will be inferred from the
    /// type of the supplementary view.
    public var reuseIdentifier: String? = nil
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
    
    public init<KindType: RawRepresentable where KindType.RawValue == String>(kind: KindType) {
        self.kind = kind.rawValue
    }
    
    /// Add a configuration block to the supplementary view. This does not clear existing configuration blocks.
    public mutating func configure<V: UICollectionReusableView, DS: DataSource>(closure: (view: V, dataSource: DS, indexPath: NSIndexPath) -> ()) {
        viewType = V.self
        
        if let old = configureView {
            // chain the old with the new
            configureView = {
                old(view: $0, dataSource: $1, indexPath: $2)
                closure(view: $0 as! V, dataSource: $1 as! DS, indexPath: $2)
            }
        } else {
            configureView = {
                closure(view: $0 as! V, dataSource: $1 as! DS, indexPath: $2)
            }
        }
    }
    
}

public struct SectionMetrics {
    
    public static var defaultMetrics: SectionMetrics {
        var metrics = SectionMetrics()
        metrics.measurement = .Default
        metrics.numberOfColumns = 1
        metrics.separatorColor = UIColor(white: 0.8, alpha: 1)
        metrics.separators = SeparatorOptions.Supplements | SeparatorOptions.Rows | SeparatorOptions.Columns
        return metrics
    }
    
    /// The size of each row in the section.
    public var measurement: ElementLength? = nil
    /// Number of columns in this section. Sections will inherit a default of
    /// 1 from the data source.
    public var numberOfColumns: Int? = nil
    /// Padding around the cells for this section. The top & bottom padding
    /// will be applied between the headers & footers and the cells. The left &
    /// right padding will be applied between the view edges and the cells.
    public var padding: UIEdgeInsets? = nil
    /// Space between this and the next section
    public var margin: CGFloat? = nil
    /// How the cells should be laid out when there are multiple columns.
    public var itemLayout: LayoutOrder? = nil
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
    /// Insets for the separators drawn between rows (left & right) and
    /// columns (top & bottom).
    public var separatorInsets: UIEdgeInsets? = nil
    /// The color to use when drawing row, column, and section separators.
    public var separatorColor: UIColor? = nil
    /// Determines where, if any, separators are drawn.
    private var didSetSeparators: Bool = false
    public var separators: SeparatorOptions = nil {
        didSet { didSetSeparators = true }
    }
    
    var hasPlaceholder = false
    
    public mutating func apply(metrics other: SectionMetrics) {
        if let otherMeasurement = other.measurement { measurement = otherMeasurement }
        if let otherColumns = other.numberOfColumns { numberOfColumns = otherColumns }
        if let otherPadding = other.padding { padding = otherPadding }
        if let otherMargin = other.margin { margin = otherMargin }
        if let otherOrder = other.itemLayout { itemLayout = otherOrder }
        if let otherBackgroundColor = other.backgroundColor { backgroundColor = otherBackgroundColor }
        if let otherSelectedBackgroundColor = other.selectedBackgroundColor { selectedBackgroundColor = otherSelectedBackgroundColor }
        if let otherTintColor = other.tintColor { tintColor = otherTintColor }
        if let otherSelectedTintColor = other.selectedTintColor { selectedTintColor = otherSelectedTintColor }
        if let otherInsets = other.separatorInsets { separatorInsets = otherInsets }
        if let otherSeparatorColor = other.separatorColor { separatorColor = otherSeparatorColor }
        if other.didSetSeparators { separators = other.separators }
        if other.hasPlaceholder { hasPlaceholder = true }
    }
    
}
