//
//  Measurement.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/31/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

/// A category of methods that makes working with reusable cells and supplementary views a bit easier.
public extension UICollectionReusableView {
    
    /// This is kind of a hack because cells don't have an intrinsic content size or any other way to constrain them to a size. As a result, labels that *should* wrap at the bounds of a cell, don't. So by adding width and height constraints to the cell temporarily, we can make the labels wrap and the layout compute correctly.
    public func preferredLayoutSize(fittingSize targetSize: CGSize) -> CGSize {
        frame.size = targetSize
        
        func update(measuredSize newSize: CGSize) -> CGSize {
            self.frame.size = newSize
            return newSize
        }
        
        if Constants.isiOS8 {
            layoutIfNeeded()
            let newSize = systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
            return update(measuredSize: newSize)
        }
        
        let constraints = [
            NSLayoutConstraint(item: self, attribute: .Width, relatedBy: .LessThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: targetSize.width),
            NSLayoutConstraint(item: self, attribute: .Height, relatedBy: .LessThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: UILayoutFittingExpandedSize.height)
        ]
        
        addConstraints(constraints)
        updateConstraintsIfNeeded()
        layoutIfNeeded()
        let newSize = systemLayoutSizeFittingSize(targetSize)
        removeConstraints(constraints)
        
        return update(measuredSize: newSize)
    }
    
}

public extension UICollectionViewCell {
    
    public override func preferredLayoutSize(fittingSize targetSize: CGSize) -> CGSize {
        frame.size = targetSize
        
        func update(measuredSize newSize: CGSize) -> CGSize {
            // Only consider the height for cells, because the contentView isn't anchored correctly sometimes.
            let fitted = CGSize(width: targetSize.width, height: newSize.height)
            self.frame.size = fitted
            return fitted
        }
        
        if Constants.isiOS8 {
            layoutIfNeeded()
            let newSize = contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
            return update(measuredSize: newSize)
        }
        
        let constraints = [
            NSLayoutConstraint(item: self, attribute: .Width, relatedBy: .LessThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: targetSize.width),
            NSLayoutConstraint(item: self, attribute: .Height, relatedBy: .LessThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: UILayoutFittingExpandedSize.height)
        ]
        
        addConstraints(constraints)
        updateConstraintsIfNeeded()
        layoutIfNeeded()
        let newSize = systemLayoutSizeFittingSize(targetSize)
        removeConstraints(constraints)
        
        return update(measuredSize: newSize)
    }
    
}

