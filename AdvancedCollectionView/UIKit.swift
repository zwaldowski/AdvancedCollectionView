//
//  UIKit.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

struct Constants {
    static let isiOS8 = floor(NSFoundationVersionNumber) > 1047.25
}

/// Extension-safe user layout direction
extension UIUserInterfaceLayoutDirection {
    
    public static let userLayoutDirection: UIUserInterfaceLayoutDirection = {
        let direction = NSParagraphStyle.defaultWritingDirectionForLanguage(nil)
        switch NSParagraphStyle.defaultWritingDirectionForLanguage(nil) {
        case .LeftToRight:
            return .LeftToRight
        case .RightToLeft:
            return .RightToLeft
        case .Natural:
            if let localization = NSBundle.mainBundle().preferredLocalizations.first as? String {
                return NSLocale.characterDirectionForLanguage(localization) == .RightToLeft ? .RightToLeft : .LeftToRight
            }
            return .LeftToRight
        }
    }()
    
}

// MARK: Size class helpers

extension UIView {
    
    var isWideHorizontal: Bool {
        if Constants.isiOS8 {
            return traitCollection.horizontalSizeClass == .Regular
        }
        return UIDevice.currentDevice().userInterfaceIdiom == .Pad
    }
    
}
