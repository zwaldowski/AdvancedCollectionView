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
