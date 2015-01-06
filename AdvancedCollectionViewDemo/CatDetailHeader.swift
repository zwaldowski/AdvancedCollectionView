//
//  CatDetailHeader.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/4/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

class CatDetailHeader: PinnableHeaderView {
    
    private weak var nameLabel: UILabel!
    private weak var descriptionLabel: UILabel!
    private weak var conservationStatusValue: UILabel!
    private weak var conservationStatusLabel: UILabel!
    
    override func commonInit() {
        super.commonInit()
        
        let name = UILabel()
        name.setTranslatesAutoresizingMaskIntoConstraints(false)
        name.font = UIFont.systemFontOfSize(24)
        name.numberOfLines = 1
        contentView.addSubview(name)
        nameLabel = name
        
        let description = UILabel()
        description.setTranslatesAutoresizingMaskIntoConstraints(false)
        description.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        description.numberOfLines = 2
        description.textColor = UIColor(white: 0.4, alpha: 1)
        contentView.addSubview(description)
        descriptionLabel = name
        
        let statusValue = UILabel()
        statusValue.setTranslatesAutoresizingMaskIntoConstraints(false)
        statusValue.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)
        statusValue.numberOfLines = 1
        statusValue.textColor = UIColor(white: 0.6, alpha: 1)
        contentView.addSubview(statusValue)
        conservationStatusValue = name
        
        let statusLabel = UILabel()
        statusLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        statusLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption2)
        statusLabel.numberOfLines = 1
        statusLabel.textColor = UIColor(white: 0.4, alpha: 1)
        contentView.addSubview(statusLabel)
        conservationStatusLabel = name
        
        let views = [
            "nameLabel": nameLabel,
            "descriptionLabel": descriptionLabel,
            "conservationStatusValue": conservationStatusValue,
            "conservationStatusLabel": conservationStatusLabel
        ]
        let metrics = [ "pad": 3 ]
        
        var constraints = [NSLayoutConstraint]()
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-[nameLabel]-(>=0)-|", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-[descriptionLabel]-(>=0)-|", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("[conservationStatusValue]-|", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-[conservationStatusLabel]-pad-[conservationStatusValue]", options: .AlignAllBaseline, metrics: metrics, views: views) as [NSLayoutConstraint]
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("V:|-[nameLabel][descriptionLabel]-pad-[conservationStatusValue]", options: nil, metrics: metrics, views: views) as [NSLayoutConstraint]
        
        contentView.addConstraints(constraints)
    }

}

extension CatDetailHeader {
    
    func configure(#cat: AAPLCat) {
        nameLabel.text = cat.name
        descriptionLabel.text = cat.shortDescription
        if let status = cat.conservationStatus {
            conservationStatusValue.text = status
            conservationStatusLabel.text = NSLocalizedString("Conservation Status:", comment: "Conservation Status Label")
        } else {
            conservationStatusValue.text = nil
            conservationStatusLabel.text = nil
        }
    }
    
}
