//
//  CatSightingCell.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/4/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

class CatSightingCell: GridCell {
    
    private weak var dateLabel: UILabel!
    private weak var fancierLabel: UILabel!
    private weak var descriptionLabel: UILabel!
    
    override func commonInit() {
        super.commonInit()
        
        let date = UILabel()
        date.setTranslatesAutoresizingMaskIntoConstraints(false)
        date.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)
        date.textColor = UIColor(white: 0.6, alpha: 1)
        date.setContentHuggingPriority(750, forAxis: .Horizontal)
        contentView.addSubview(date)
        dateLabel = date
        
        let fancier = UILabel()
        fancier.setTranslatesAutoresizingMaskIntoConstraints(false)
        fancier.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        contentView.addSubview(fancier)
        fancierLabel = fancier
        
        let description = UILabel()
        description.setTranslatesAutoresizingMaskIntoConstraints(false)
        description.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption2)
        description.textColor = UIColor(white: 0.4, alpha: 1)
        contentView.addSubview(description)
        descriptionLabel = description
        
        let views = [
            "dateLabel": date,
            "fancierLabel": fancier,
            "descriptionLabel": description
        ]
        let metrics = [ "vPad": 3 ]
        
        var constraints = [NSLayoutConstraint]()
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-[fancierLabel]-[dateLabel]-|", options: .AlignAllBaseline, metrics: metrics, views: views) as! [NSLayoutConstraint]
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-[descriptionLabel]-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("V:|-vPad-[fancierLabel][descriptionLabel]-vPad-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
        contentView.addConstraints(constraints)
    }
    
}

extension CatSightingCell {
    
    func configure(catSighting: CatSighting?, dateFormatter: NSDateFormatter) {
        dateLabel.text = dateFormatter.stringFromDate(catSighting?.date ?? NSDate())
        fancierLabel.text = catSighting?.catFancier
        descriptionLabel.text = catSighting?.shortDescription
    }
    
}
