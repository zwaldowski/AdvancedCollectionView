//
//  BasicCell.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

private func primaryFont() -> UIFont {
    return UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)
}

private func secondaryFont() -> UIFont {
    return UIFont.preferredFontForTextStyle(UIFontTextStyleCaption2)
}

/// A basic collection view cell with a primary and secondary label.
public class BasicCell: GridCell {
    
    public enum Style {
        /// Primary and secondary labels are the same size with the primary label left aligned and the secondary right aligned
        case Default
        /// Primary and secondary labels are aligned one above the other. Primary label is larger than the secondary label.
        case Subtitle
    }
    
    public var style: Style = .Default {
        didSet {
            invalidateConstraints()
        }
    }
    
    public var contentInsets: UIEdgeInsets = UIEdgeInsets() {
        didSet {
            invalidateConstraints()
        }
    }
    
    private(set) public weak var primaryLabel: UILabel!
    private(set) public weak var secondaryLabel: UILabel!
    private var constraints = [NSLayoutConstraint]()
    
    public override func commonInit() {
        super.commonInit()
        
        let primary = UILabel()
        primary.setTranslatesAutoresizingMaskIntoConstraints(false)
        primary.numberOfLines = 1
        primary.font = primaryFont()
        contentView.addSubview(primary)
        primaryLabel = primary
        
        let secondary = UILabel()
        secondary.setTranslatesAutoresizingMaskIntoConstraints(false)
        secondary.numberOfLines = 1
        secondary.font = secondaryFont()
        contentView.addSubview(secondary)
        secondaryLabel = secondary
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        
        primaryLabel.font = primaryFont()
        secondaryLabel.font = secondaryFont()
    }
    
    public override func updateConstraints() {
        if !constraints.isEmpty {
            super.updateConstraints()
            return
        }
        
        let labelHeight: CGFloat = {
            let primaryHeight = self.primaryLabel.font.lineHeight
            let secondaryHeight = self.secondaryLabel.font.lineHeight
            
            switch self.style {
            case .Default:
                return max(primaryHeight, secondaryHeight)
            case .Subtitle:
                return primaryHeight + secondaryHeight
            }
        }()
        
        // Our content insets are based on a 44pt row height
        let vPad = max(0, (44 - labelHeight) / 2)
        let hPad = CGFloat(15)
        
        contentInsets = UIEdgeInsets(top: vPad, left: hPad, bottom: vPad, right: hPad)
        
        let metrics = [
            "top": vPad,
            "bottom": vPad,
            "left": hPad,
            "right": hPad
        ]
        let views = [
            "primary": primaryLabel,
            "secondary": secondaryLabel
        ]
        
        switch style {
        case .Default:
            constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-left-[primary]-(>=10)-[secondary]-right-|", options: .AlignAllBaseline, metrics: metrics, views: views) as! [NSLayoutConstraint]
            constraints.append(NSLayoutConstraint(item: primaryLabel, attribute: .CenterY, relatedBy: .Equal, toItem: contentView, attribute: .CenterY, multiplier: 1, constant: 0))
            constraints.append(NSLayoutConstraint(item: primaryLabel, attribute: .Height, relatedBy: .LessThanOrEqual, toItem: contentView, attribute: .Height, multiplier: 1, constant: 0))
            break
        case .Subtitle:
            constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-left-[primary]-(>=right)-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
            constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-left-[secondary]-(>=right)-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
            constraints += NSLayoutConstraint.constraintsWithVisualFormat("V:|-top-[primary][secondary]-bottom-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
            break
        }
        
        addConstraints(constraints)
        super.updateConstraints()
    }
    
    public override func invalidateConstraints() {
        removeConstraints(constraints)
        constraints.removeAll()
        super.invalidateConstraints()
    }
    
}
