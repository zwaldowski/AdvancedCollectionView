//
//  PinnableHeaderView.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

func defaultPinnableBorderColor() -> UIColor {
    return UIColor(white: 0.8, alpha: 1)
}

// A subclass-ready section header view for pinnable headers.
public class PinnableHeaderView: GridCell {
    
    private weak var borderView: HairlineView!
    private var backgroundColorBeforePinning: UIColor?
    
    public override func commonInit() {
        super.commonInit()
        
        backgroundColor = UIColor.whiteColor()
        
        let border = HairlineView(frame: CGRect.zeroRect)
        border.setTranslatesAutoresizingMaskIntoConstraints(false)
        addSubview(border)
        borderView = border
        
        let views = [ "borderView": border ]
        
        var constraints = [NSLayoutConstraint]()
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|[borderView]|", options: nil, metrics: nil, views: views) as [NSLayoutConstraint]
        constraints.append(NSLayoutConstraint(item: border, attribute: .Bottom, relatedBy: .Equal, toItem: self, attribute: .Bottom, multiplier: 1, constant: 0))
        addConstraints(constraints)
    }
    
    /// Property updated by the collection view grid layout when the header is pinned to the top of the collection view.
    private var __pinned = false
    public var pinned: Bool { return __pinned }

    private func setPinned(pinned: Bool, animated: Bool) {
        __pinned = pinned
        
        let actions = { () -> () in
            if pinned {
                self.backgroundColorBeforePinning = self.backgroundColor
                if self.backgroundColorWhenPinned != nil {
                    self.backgroundColor = self.backgroundColorWhenPinned
                }
            } else {
                self.backgroundColor = self.backgroundColorBeforePinning;
            }
            
            let borderColor = (pinned ? self.bottomBorderColorWhenPinned : nil) ?? self.bottomBorderColor
            let hideBorder = borderColor == nil
            
            self.borderView.backgroundColor = borderColor
            self.borderView.hidden = hideBorder
        }
        
        if animated {
            UIView.animateWithDuration(0.25, animations: actions)
        } else {
            actions()
        }
    }

    /// The color of the bottom border. If nil, the bottom border is not shown.
    public var bottomBorderColor: UIColor? = defaultPinnableBorderColor() {
        didSet {
            if pinned { return }
            borderView.backgroundColor = bottomBorderColor
            borderView.hidden = bottomBorderColor == nil
        }
    }
    
    /// The color of the border to add to the header when it is pinned. A nil value indicates no border should be added.
    public var bottomBorderColorWhenPinned: UIColor? = defaultPinnableBorderColor() {
        didSet {
            if !pinned { return }
            borderView.backgroundColor = bottomBorderColorWhenPinned
            borderView.hidden = bottomBorderColorWhenPinned == nil
        }
    }
    
    /// The background color to display when the header has been pinned. A nil value indicates the header should blend with navigation bars.
    public var backgroundColorWhenPinned: UIColor? = nil
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        
        setPinned(false, animated: false)
        bottomBorderColor = defaultPinnableBorderColor()
        bottomBorderColorWhenPinned = defaultPinnableBorderColor()
        backgroundColorWhenPinned = nil
    }

    public override func applyLayoutAttributes(layoutAttributes: UICollectionViewLayoutAttributes!) {
        super.applyLayoutAttributes(layoutAttributes)
        
        if let attributes = layoutAttributes as? GridLayoutAttributes {
            // If we're not pinned, then immediately set the background colour, otherwise, remember it for when we restore the background color
            if !pinned {
                backgroundColor = attributes.backgroundColor
            } else {
                backgroundColorBeforePinning = attributes.backgroundColor
            }
            
            setPinned(attributes.pinned, animated: true)
        }
    }
    
}
