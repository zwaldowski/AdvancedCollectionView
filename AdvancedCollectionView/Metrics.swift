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
    public init(rawValue value: UInt) { self.rawValue = value }
    public init(nilLiteral: ()) { self.init(rawValue: 0) }
    
    public let rawValue: UInt
    
    public static var allZeros: SeparatorOptions { return nil }
    public static var BeforeSections: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 0) }
    public static var Supplements: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 1) }
    public static var Rows: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 2) }
    public static var Columns: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 3) }
    public static var AfterSections: SeparatorOptions { return SeparatorOptions(rawValue: 1 << 4) }
}

// MARK: Supplementary Metrics

public typealias ConfigureSupplement = (view: UICollectionReusableView, dataSource: DataSource, indexPath: NSIndexPath) -> ()

private final class SupplementaryMetricsStorage {
    
    /// The kind of supplementary view these metrics describe
    let kind: String
    init(kind: String) {
        self.kind = kind
    }

    var viewType = UICollectionReusableView.self
    var isVisibleWhileShowingPlaceholder = false
    var shouldPin = false
    var measurement: ElementLength?
    var isHidden = false
    var padding = UIEdgeInsets()
    var zIndex = GridLayout.ZIndex.Supplement.rawValue
    var reuseIdentifier: String? = nil
    var backgroundColor: UIColor? = nil
    var selectedBackgroundColor: UIColor? = nil
    var tintColor: UIColor? = nil
    var selectedTintColor: UIColor? = nil
    var configureView: ConfigureSupplement?
    
    func clone(fn: SupplementaryMetricsStorage -> ()) -> SupplementaryMetricsStorage {
        var ret = self.dynamicType(kind: kind)
        ret.viewType = viewType
        ret.isVisibleWhileShowingPlaceholder = isVisibleWhileShowingPlaceholder
        ret.shouldPin = shouldPin
        ret.measurement = measurement
        ret.isHidden = isHidden
        ret.padding = padding
        ret.zIndex = zIndex
        ret.reuseIdentifier = reuseIdentifier
        ret.backgroundColor = backgroundColor
        ret.selectedBackgroundColor = selectedBackgroundColor
        ret.tintColor = tintColor
        ret.selectedTintColor = selectedTintColor
        ret.configureView = configureView
        fn(ret)
        return ret
    }
    
}

public struct SupplementaryMetrics {

    private var storage: SupplementaryMetricsStorage
    
    /// Initialize with a member of a kind type enumeration
    public init<KindType: RawRepresentable where KindType.RawValue == String>(kind: KindType) {
        self.storage = SupplementaryMetricsStorage(kind: kind.rawValue)
    }

    /// The kind of supplementary view these metrics describe
    public var kind: String {
        return storage.kind
    }
    
    /// Copy-on write setter
    private mutating func modifyStorage(fn: (SupplementaryMetricsStorage -> ())) {
        if isUniquelyReferencedNonObjC(&storage) {
            fn(storage)
        } else {
            storage = storage.clone(fn)
        }
    }

    /// The class to use when dequeuing an instance of this supplementary view
    public var viewType: UICollectionReusableView.Type {
        get { return storage.viewType }
        set { modifyStorage {
                $0.viewType = newValue
        }}
    }
    
    /// Should this supplementary view be displayed while the placeholder is visible?
    public var isVisibleWhileShowingPlaceholder: Bool {
        get { return storage.isVisibleWhileShowingPlaceholder }
        set { modifyStorage {
            $0.isVisibleWhileShowingPlaceholder = newValue
        }}
    }
    
    /// Should this supplementary view be pinned to the edges of the view when
    /// scrolling? Only valid for headers and footers.
    public var shouldPin: Bool {
        get { return storage.shouldPin }
        set { modifyStorage {
            $0.shouldPin = newValue
        }}
    }
    
    /// The size of the supplementary view relative to the layout.
    public var measurement: ElementLength? {
        get { return storage.measurement }
        set { modifyStorage {
            $0.measurement = newValue
        }}
    }
    
    /// Should the supplementary view be hidden?
    public var isHidden: Bool {
        get { return storage.isHidden }
        set { modifyStorage {
            $0.isHidden = newValue
        }}
    }
    
    /// Use top & bottom padding to adjust spacing of header & footer elements.
    /// Not all headers & footers adhere to padding. Default @c UIEdgeInsets()
    /// which is interpretted by supplementary items to be their default values.
    public var padding: UIEdgeInsets {
        get { return storage.padding }
        set { modifyStorage {
            $0.padding = newValue
        }}
    }
    
    /// How is this affected by other coinciding views?
    public var zIndex: Int {
        get { return storage.zIndex }
        set { modifyStorage {
            $0.zIndex = newValue
        }}
    }
    
    /// Optional reuse identifier. If not specified, it will be inferred from the
    /// type of the supplementary view.
    public var reuseIdentifier: String! {
        get {
            if let ret = storage.reuseIdentifier {
                return ret
            }
            return NSStringFromClass(viewType)
        }
        set { modifyStorage {
            $0.reuseIdentifier = newValue
        }}
    }
    
    /// The background color that should be used for this element. On an item,
    /// if not set, this will be inherited from the section.
    public var backgroundColor: UIColor? {
        get { return storage.backgroundColor }
        set { modifyStorage {
            $0.backgroundColor = newValue
        }}
    }
    
    /// The background color shown when this element is selected. On an item, if
    /// not set, this will be inherited from the section. Use the clear color
    /// to override a selection color from the section.
    public var selectedBackgroundColor: UIColor? {
        get { return storage.selectedBackgroundColor }
        set { modifyStorage {
            $0.selectedBackgroundColor = newValue
        }}
    }
    
    /// The preferred tint color used for this element. On an item, if not set,
    /// not set, it will be inherited from the section.
    public var tintColor: UIColor? {
        get { return storage.tintColor }
        set { modifyStorage {
            $0.tintColor = newValue
        }}
    }
    
    /// The preferred tint color used for this element when selected. On an
    /// item, if not set, it will be inherited from the section. Use the clear
    /// color to override the inherited color.
    public var selectedTintColor: UIColor? {
        get { return storage.selectedTintColor }
        set { modifyStorage {
            $0.selectedTintColor = newValue
        }}
    }
    
    /// Add a configuration block to the supplementary view. This does not clear existing configuration blocks.
    public mutating func configure<V: UICollectionReusableView, DS: DataSource>(newConfigurator: (view: V, dataSource: DS, indexPath: NSIndexPath) -> ()) {
        let oldConfigurator: ConfigureSupplement
        if let old = storage.configureView {
            oldConfigurator = old
        } else {
            oldConfigurator = { (_, _, _) -> () in }
        }
        
        let chained: ConfigureSupplement = {
            oldConfigurator(view: $0, dataSource: $1, indexPath: $2)
            newConfigurator(view: $0 as! V, dataSource: $1 as! DS, indexPath: $2)
        }
        
        modifyStorage {
            $0.viewType = V.self
            $0.configureView = chained
        }
    }
    
    func configureView(#view: UICollectionReusableView, dataSource: DataSource, indexPath: NSIndexPath) {
        storage.configureView?(view: view, dataSource: dataSource, indexPath: indexPath)
    }

}

// MARK: Section Metrics

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
