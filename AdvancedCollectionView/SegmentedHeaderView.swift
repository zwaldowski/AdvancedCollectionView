//
//  SegmentedHeaderView.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

/// A header view with a segmented control for displaying titles of child data sources in a segmented data source.
public class SegmentedHeaderView: GridCell {
    
    private(set) public weak var segmentedControl: UISegmentedControl!
    private var segmentedControlConstraints = [NSLayoutConstraint]()
    
    public override func commonInit() {
        super.commonInit()

        let control = UISegmentedControl()
        control.setTranslatesAutoresizingMaskIntoConstraints(false)
        control.setContentHuggingPriority(750, forAxis: .Vertical)
        contentView.addSubview(control)
        segmentedControl = control
    }
    
    public override var defaultPadding: UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
    }
    
    public override func invalidateConstraints() {
        contentView.removeConstraints(segmentedControlConstraints)
        segmentedControlConstraints.removeAll()
        super.invalidateConstraints()
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        segmentedControl.removeTarget(nil, action: nil, forControlEvents: .AllEvents)
    }
    
    public override func updateConstraints() {
        if !segmentedControlConstraints.isEmpty {
            super.updateConstraints()
            return
        }
        
        let metrics = [
            "topMargin": padding.top,
            "leftMargin": padding.left,
            "bottomMargin": padding.bottom,
            "rightMargin": padding.right
        ]
        let views = [ "segmentedControl": segmentedControl ]
        
        segmentedControlConstraints += NSLayoutConstraint.constraintsWithVisualFormat("V:|-topMargin-[segmentedControl]-bottomMargin-|", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        
        if isWideHorizontal {
            segmentedControlConstraints.append(NSLayoutConstraint(item: segmentedControl, attribute: .CenterX, relatedBy: .Equal, toItem: self, attribute: .CenterX, multiplier: 1, constant: 0))
            segmentedControlConstraints.append(NSLayoutConstraint(item: segmentedControl, attribute: .Width, relatedBy: .LessThanOrEqual, toItem: self, attribute: .Width, multiplier: 1, constant: -padding.left - padding.right))
        } else {
            segmentedControlConstraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-leftMargin-[segmentedControl]-rightMargin-|", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        }
        
        contentView.addConstraints(segmentedControlConstraints)
        
        super.updateConstraints()
    } 
    
}
