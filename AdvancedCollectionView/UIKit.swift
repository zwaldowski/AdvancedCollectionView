//
//  UIKit.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

struct Constants {
    static let isiOS8 = floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1
    static let isiOS7 = floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1 && !isiOS8
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

// MARK: Constraint conveniences

public extension NSLayoutConstraint {
    
    convenience init(from item1: UIView, attribute attribute1: NSLayoutAttribute, by relation: NSLayoutRelation = .Equal, to item2: UIView? = nil, attribute attribute2: NSLayoutAttribute = .NotAnAttribute, times multiplier: CGFloat = 1, plus constant: CGFloat = 0, at priority: UILayoutPriority = 1000) {
        self.init(item: item1, attribute: attribute1, relatedBy: relation, toItem: item2, attribute: attribute2, multiplier: multiplier, constant: constant)
        self.priority = priority
    }

}

public func makeConstraints<View: UIView>(#format: String, options: NSLayoutFormatOptions = nil, metrics: [String: CGFloat]? = nil, views: [String: View]) -> [NSLayoutConstraint] {
    return NSLayoutConstraint.constraintsWithVisualFormat(format, options: options, metrics: metrics, views: views) as! [NSLayoutConstraint]
}

public func makeConstraints<View: UIView>(#format: String, options: NSLayoutFormatOptions = nil, #metrics: [String: Int], views: [String: View]) -> [NSLayoutConstraint] {
    return NSLayoutConstraint.constraintsWithVisualFormat(format, options: options, metrics: metrics, views: views) as! [NSLayoutConstraint]
}

public func appendConstraints<Constraints: ExtensibleCollectionType, View: UIView where Constraints.Generator.Element == NSLayoutConstraint>(inout constraints: Constraints, #format: String, options: NSLayoutFormatOptions = nil, metrics: [String: CGFloat]? = nil, views: [String: View]) {
    let newConstraints: [NSLayoutConstraint] = NSLayoutConstraint.constraintsWithVisualFormat(format, options: options, metrics: metrics, views: views) as! [NSLayoutConstraint]
    constraints.extend(newConstraints)
}

public func appendConstraints<Constraints: ExtensibleCollectionType, View: UIView where Constraints.Generator.Element == NSLayoutConstraint>(inout constraints: Constraints, #format: String, options: NSLayoutFormatOptions = nil, #metrics: [String: Int], views: [String: View]) {
    let newConstraints: [NSLayoutConstraint] = NSLayoutConstraint.constraintsWithVisualFormat(format, options: options, metrics: metrics, views: views) as! [NSLayoutConstraint]
    constraints.extend(newConstraints)
}

public func appendConstraint<Constraints: ExtensibleCollectionType where Constraints.Generator.Element == NSLayoutConstraint>(inout constraints: Constraints, from item1: UIView, attribute attribute1: NSLayoutAttribute, by relation: NSLayoutRelation = .Equal, to item2: UIView? = nil, attribute attribute2: NSLayoutAttribute = .NotAnAttribute, times multiplier: CGFloat = 1, plus constant: CGFloat = 0, at priority: UILayoutPriority = 1000) {
    let newConstraint = NSLayoutConstraint(item: item1, attribute: attribute1, relatedBy: relation, toItem: item2, attribute: attribute2, multiplier: multiplier, constant: constant)
    newConstraint.priority = priority
    constraints.append(newConstraint)
}
