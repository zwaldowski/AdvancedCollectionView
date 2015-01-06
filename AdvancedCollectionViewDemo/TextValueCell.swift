//
//  TextValueCell.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/4/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

class TextValueCell: AdvancedCollectionView.CollectionViewCell {
    
    private weak var label: UILabel!
    
    override func commonInit() {
        super.commonInit()
        
        let label = UILabel()
        label.setTranslatesAutoresizingMaskIntoConstraints(false)
        contentView.addSubview(label)
        self.label = label
        
        let views = [ "label": label ]
        let metrics = [ "hPad": 15, "vPad": 3 ]
        var constraints = [NSLayoutConstraint]()
        
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-hPad-[label]-hPad-|", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("V:|-vPad-[label]-vPad-|", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        
        contentView.addConstraints(constraints)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        label.preferredMaxLayoutWidth = contentView.bounds.width
        super.layoutSubviews()
    }
    
}

extension TextValueCell {
    
    func configure(text: String) {
        label.text = text
    }
    
}
