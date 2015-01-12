//
//  HairlineView.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

private func hairlineColor() -> UIColor {
    return UIColor(white: 0.8, alpha: 1)
}

/// A simple view that is ALWAYS a hairline thickness, either in width or height. By default the background color is a medium grey.
class HairlineView: UIView {
    
    private var axis: UILayoutConstraintAxis = .Horizontal {
        didSet {
            setContentHuggingPriority(250, forAxis: axis)
            setContentHuggingPriority(1000, forAxis: axis)
            invalidateIntrinsicContentSize()
        }
    }
    
    func commonInit() {
        backgroundColor = hairlineColor()
    }
    
    override init(frame: CGRect = CGRect.zeroRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        commonInit()
    }
    
    override var frame: CGRect {
        didSet {
            axis = frame.width >= frame.height ? .Horizontal : .Vertical
        }
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        if size.width > size.height {
            return CGSize(width: size.width, height: hairline)
        } else {
            return CGSize(width: hairline, height: size.height)
        }
    }
    
    override func intrinsicContentSize() -> CGSize {
        switch axis {
        case .Horizontal:
            return CGSize(width: UIViewNoIntrinsicMetric, height: hairline)
        case .Vertical:
            return CGSize(width: hairline, height: UIViewNoIntrinsicMetric)
        }
    }
        
}
