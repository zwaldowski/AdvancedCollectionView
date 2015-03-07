//
//  GridLayoutAttributes.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit
import ObjectiveC.runtime

private var contentOffsetAdjustmentLegacyKey = 0
private var contentSizeAdjustmentLegacyKey = 0

public final class GridLayoutAttributes: UICollectionViewLayoutAttributes {
    
    /// The background color for the view
    public var backgroundColor: UIColor? = nil
    /// The background color when selected
    public var selectedBackgroundColor: UIColor? = nil
    /// The background color for the view
    public var tintColor: UIColor? = nil
    /// The background color when selected
    public var selectedTintColor: UIColor? = nil
    /// Used by supplementary items
    public var padding = UIEdgeInsets()
    
    /// If this is a header, is it pinned to the top of the collection view?
    /// If this is pinned, where is our minY when we unpin it?
    var pinning: (isPinned: Bool, isHiddenNormally: Bool, unpinnedY: CGFloat?) = (false, false, nil)
    /// What is the column index for this item?
    var columnIndex = 0
    
    public override var hash: Int {
        var hash = SimpleHash(super.hash)
        hash.append(backgroundColor?.hashValue)
        hash.append(selectedBackgroundColor?.hashValue)
        hash.append(tintColor?.hashValue)
        hash.append(selectedTintColor?.hashValue)
        hash.append(padding.top.hashValue)
        hash.append(padding.left.hashValue)
        hash.append(padding.bottom.hashValue)
        hash.append(padding.right.hashValue)
        hash.append(pinning.isPinned.hashValue)
        hash.append(pinning.isHiddenNormally.hashValue)
        hash.append(pinning.unpinnedY?.hashValue)
        hash.append(columnIndex.hashValue)
        return hash.result
    }
    
    public override func isEqual(object: AnyObject?) -> Bool {
        if !super.isEqual(object) { return false }
        if let other = object as? GridLayoutAttributes {
            if backgroundColor != other.backgroundColor { return false }
            if selectedBackgroundColor != other.selectedBackgroundColor { return false }
            if tintColor != other.tintColor { return false }
            if selectedTintColor != other.selectedTintColor { return false }
            if padding != other.padding { return false }
            if pinning.isPinned != other.pinning.isPinned { return false }
            if pinning.isHiddenNormally != other.pinning.isHiddenNormally { return false }
            if pinning.unpinnedY != other.pinning.unpinnedY { return false }
            if columnIndex != other.columnIndex { return false }
            return true
        } else {
            return false
        }
    }
    
    public override func copyWithZone(zone: NSZone) -> AnyObject {
        var attributes = super.copyWithZone(zone) as! GridLayoutAttributes
        attributes.backgroundColor = backgroundColor
        attributes.selectedBackgroundColor = selectedBackgroundColor
        attributes.tintColor = tintColor
        attributes.selectedTintColor = selectedTintColor
        attributes.padding = padding
        attributes.pinning = pinning
        attributes.columnIndex = columnIndex
        return attributes
    }
    
}

public class GridLayoutInvalidationContext: UICollectionViewLayoutInvalidationContext {

    public override var contentOffsetAdjustment: CGPoint {
        get {
            if Constants.isiOS8 {
                return super.contentOffsetAdjustment
            } else if let obj = objc_getAssociatedObject(self, &contentOffsetAdjustmentLegacyKey) as? NSValue {
                return obj.CGPointValue()
            } else {
                return CGPoint()
            }
        }
        set {
            if Constants.isiOS8 {
                super.contentOffsetAdjustment = newValue
            } else {
                let obj = NSValue(CGPoint: newValue)
                objc_setAssociatedObject(self, &contentOffsetAdjustmentLegacyKey, obj, UInt(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
            }
        }
    }
    
    public override var contentSizeAdjustment: CGSize {
        get {
            if Constants.isiOS8 {
                return super.contentSizeAdjustment
            } else if let obj = objc_getAssociatedObject(self, &contentSizeAdjustmentLegacyKey) as? NSValue {
                return obj.CGSizeValue()
            } else {
                return CGSize()
            }
        }
        set {
            if Constants.isiOS8 {
                super.contentSizeAdjustment = newValue
            } else {
                let obj = NSValue(CGSize: newValue)
                objc_setAssociatedObject(self, &contentOffsetAdjustmentLegacyKey, obj, UInt(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
            }
            
        }
    }
    
    public var invalidateLayoutMetrics = true
    public var invalidateLayoutOrigin = false
    
}
