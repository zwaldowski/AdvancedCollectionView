//
//  GridCell.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

/// The base collection view cell used by the grid layout code.
public class GridCell: UICollectionViewCell {
    
    public override class func requiresConstraintBasedLayout() -> Bool {
        return true
    }
    
    public func commonInit() {
        backgroundView = UIView()
        selectedBackgroundView = UIView()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        commonInit()
    }
    
    // MARK: UICollectionReusableView
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        
        highlighted = false
        enabled = true
        onTapHandler = nil
    }
    
    public override func applyLayoutAttributes(layoutAttributes: UICollectionViewLayoutAttributes!) {
        super.applyLayoutAttributes(layoutAttributes)
        
        isNotAnItem = layoutAttributes.representedElementCategory != .Cell
        
        if let attributes = layoutAttributes as? GridLayoutAttributes {
            hidden = layoutAttributes.hidden
            if attributes.padding == UIEdgeInsetsZero {
                padding = defaultPadding
            } else {
                padding = attributes.padding
            }
            backgroundView?.backgroundColor = attributes.backgroundColor
            selectedBackgroundView?.backgroundColor = attributes.selectedBackgroundColor
        } else {
            hidden = false
            padding = defaultPadding
            backgroundView?.backgroundColor = nil
            selectedBackgroundView?.backgroundColor = nil
        }
    }
    
    public override var highlighted: Bool {
        didSet {
            if highlighted {
                insertSubview(selectedBackgroundView, aboveSubview: backgroundView!)
                selectedBackgroundView.alpha = 1
                selectedBackgroundView.hidden = false
            } else {
                selectedBackgroundView.hidden = true
            }
        }
    }
    
    // MARK: UIView
    
    public override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        super.touchesBegan(touches, withEvent: event)
        
        if manualTapSupport && enabled {
            highlighted = true
        }
    }
    
    public override func touchesEnded(touches: Set<NSObject>, withEvent event: UIEvent) {
        super.touchesEnded(touches, withEvent: event)
        
        if manualTapSupport {
            highlighted = false
        }
    }
    
    public override func touchesCancelled(touches: Set<NSObject>!, withEvent event: UIEvent!) {
        super.touchesCancelled(touches, withEvent: event)
        
        if manualTapSupport {
            highlighted = false
        }
    }
    
    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        invalidateConstraints()
    }
    
    // MARK:
    
    public func invalidateConstraints() {
        setNeedsUpdateConstraints()
    }
    
    /// Default padding values preferred by the header/footer view.
    public var defaultPadding: UIEdgeInsets {
        return UIEdgeInsetsZero
    }
    
    /// Padding specified by the configuration. Can be used to update constraints.
    public var padding: UIEdgeInsets = UIEdgeInsetsZero {
        didSet {
            invalidateConstraints()
        }
    }
    
    /// Ignored for cells.
    public var enabled: Bool = false {
        didSet {
            tap?.enabled = enabled
            
            if manualTapSupport {
                if !enabled { highlighted = false }
                
                // cancel touches
                userInteractionEnabled = false
                userInteractionEnabled = true
            }
        }
    }
    
    /// Ignored for cells.
    private var onTapHandler: (() -> ())? = nil {
        didSet {
            switch (onTapHandler, isNotAnItem) {
            case (.Some, _):
                manualTapSupport = true
            case (.None, false):
                manualTapSupport = false
            default: break
            }
        }
    }
        
    @objc private func onTap(sender: UITapGestureRecognizer) {
        if let handler = onTapHandler {
            handler()
        }
    }
    
    private var isNotAnItem: Bool = false
    
    private weak var tap: UITapGestureRecognizer?
    public var manualTapSupport: Bool {
        get {
            return tap != nil
        }
        set {
            switch (manualTapSupport, tap) {
            case (true, .None):
                let gesture = UITapGestureRecognizer(target: self, action: "onTap:")
                addGestureRecognizer(gesture)
                tap = gesture
            case (false, .Some(let gesture)):
                removeGestureRecognizer(gesture)
            default:
                break
            }
        }
    }
    
}
