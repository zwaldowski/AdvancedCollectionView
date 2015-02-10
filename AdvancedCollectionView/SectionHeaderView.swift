//
//  SectionHeaderView.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

private func primaryFont() -> UIFont {
    return UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
}

private func secondaryFont() -> UIFont {
    return UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
}

/// A header view with a text label on the left or right with an optional button on the right.
public class SectionHeaderView: GridCell {
    
    private(set) public weak var leadingLabel: UILabel!
    private(set) public weak var trailingLabel: UILabel!
    
    private weak var _actionButton: UIButton?
    private func createActionButton() -> UIButton {
        let button = UIButton.buttonWithType(.System) as! UIButton
        button.setTranslatesAutoresizingMaskIntoConstraints(false)
        button.titleLabel?.font = secondaryFont()
        button.setTitleColor(UIColor(white: 0.46, alpha: 1), forState: .Disabled)
        
        contentView.addSubview(button)
        _actionButton = button
        invalidateConstraints()
        
        return button
    }
    
    var actionButton: UIButton {
        return _actionButton ?? createActionButton()
    }
    
    // MARK:
    
    public override func commonInit() {
        super.commonInit()
        
        let left = UILabel()
        left.setTranslatesAutoresizingMaskIntoConstraints(false)
        left.font = primaryFont()
        contentView.addSubview(left)
        leadingLabel = left
        
        let right = UILabel()
        right.setTranslatesAutoresizingMaskIntoConstraints(false)
        right.setContentHuggingPriority(750, forAxis: .Horizontal)
        right.font = secondaryFont()
        contentView.addSubview(right)
        trailingLabel = right
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        
        _actionButton?.removeFromSuperview()
        leadingLabel.font = primaryFont()
        leadingLabel.text = nil
        trailingLabel.font = secondaryFont()
        trailingLabel.text = nil
    }
    
    // MARK:
    
    private var constraints = [NSLayoutConstraint]()

    public override func updateConstraints() {
        if !constraints.isEmpty {
            super.updateConstraints()
            return
        }
        
        let metrics = [
            "top": padding.top,
            "left": padding.left,
            "bottom": padding.bottom,
            "right": padding.right
        ]
        var views: [String: UIView] = [ "leading": leadingLabel, "trailing": trailingLabel ]
        
        if let button = _actionButton {
            views["button"] = button
            constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-left-[leading]-(>=10)-[trailing]-5-[button]-right-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
        } else {
            constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-left-[leading]-(>=10)-[trailing]-right-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
        }

        constraints += NSLayoutConstraint.constraintsWithVisualFormat("V:|-top-[leading]-bottom-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
        
        contentView.addConstraints(constraints)
        super.updateConstraints()
    }
    
    public override var defaultPadding: UIEdgeInsets {
        return UIEdgeInsets(top: 15, left: 15, bottom: 5, right: 15)
    }
    
    public override func invalidateConstraints() {
        contentView.removeConstraints(constraints)
        constraints.removeAll()
        super.invalidateConstraints()
    }
    
}
