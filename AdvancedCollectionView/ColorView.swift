//
//  ColorView.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

/// A decoration view that applies its background color from its attributes.
public class ColorView : UICollectionReusableView {
    
    public override func applyLayoutAttributes(layoutAttributes: UICollectionViewLayoutAttributes!) {
        super.applyLayoutAttributes(layoutAttributes)
        
        if let attributes = layoutAttributes as? GridLayoutAttributes {
            backgroundColor = attributes.backgroundColor
        } else {
            backgroundColor = nil
        }
    }
    
}
