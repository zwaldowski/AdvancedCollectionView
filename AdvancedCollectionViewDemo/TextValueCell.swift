//
//  TextValueCell.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/4/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

class TextValueCell: GridCell {
    
    private weak var label: UILabel!
    
    override func commonInit() {
        super.commonInit()
        
        let label = UILabel()
        label.setTranslatesAutoresizingMaskIntoConstraints(false)
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        label.textColor = UIColor(white: 0.3, alpha: 1)
        label.lineBreakMode = .ByWordWrapping
        label.numberOfLines = 0
        contentView.addSubview(label)
        self.label = label
        
        let views = [ "label": label ]
        let metrics = [ "hPad": 15, "vPad": 3 ]
        var constraints = [NSLayoutConstraint]()
        
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-hPad-[label]-(>=hPad)-|", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("V:|-vPad-[label]-vPad-|", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        
        contentView.addConstraints(constraints)
    }
    
    override func layoutSubviews() {
        label.preferredMaxLayoutWidth = bounds.width - 30;
        super.layoutSubviews()
    }
    
}

extension TextValueCell {
    
    func configure(text: String?) {
        label.text = text
    }
    
}
