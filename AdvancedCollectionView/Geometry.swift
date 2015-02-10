//
//  Geometry.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import CoreGraphics
import UIKit.UIGeometry

// MARK: Rounding

public protocol Scalable: Comparable {
    func *(lhs: Self, rhs: Self) -> Self
    func /(lhs: Self, rhs: Self) -> Self
    static var identityScalar: Self { get }
}

extension Float: Scalable {
    public static let identityScalar = Float(1)
}

extension Double: Scalable {
    public static let identityScalar = Double(1)
}

extension CGFloat: Scalable {
    public static let identityScalar = CGFloat(CGFloat.NativeType.identityScalar)
}

private func rround<T: Scalable>(value: T, scale: T = T.identityScalar, function: T -> T) -> T {
    return (scale > T.identityScalar) ? (function(value * scale) / scale) : function(value)
}

// MARK: Approximate equality (for UI purposes)

public protocol ApproximatelyEquatable: AbsoluteValuable, Comparable {
    static var accuracy: Self { get }
}

extension Float: ApproximatelyEquatable {
    public static let accuracy = FLT_EPSILON
}

extension Double: ApproximatelyEquatable {
    public static let accuracy = DBL_EPSILON
}

extension CGFloat: ApproximatelyEquatable {
    public static let accuracy = CGFloat(CGFloat.NativeType.accuracy)
}

infix operator ~== { associativity none precedence 130 }
infix operator !~== { associativity none precedence 130 }

public func ~== <T: ApproximatelyEquatable>(lhs: T, rhs: T) -> Bool {
    return T.abs(rhs - lhs) <= T.accuracy
}

public func ~== <T: ApproximatelyEquatable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case (.Some(let l), .Some(let r)):
        return l ~== r
    default:
        return false
    }
}

public func !~== <T: ApproximatelyEquatable>(lhs: T, rhs: T) -> Bool {
    return !(lhs ~== rhs)
}

public func !~== <T: ApproximatelyEquatable>(lhs: T?, rhs: T?) -> Bool {
    return !(lhs ~== rhs)
}

// MARK: Edge insets

public func ==(lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> Bool {
    return UIEdgeInsetsEqualToEdgeInsets(lhs, rhs)
}

extension UIEdgeInsets: Equatable {
    
    private func insetsByRemoving(#edges: UIRectEdge) -> UIEdgeInsets {
        var ret = self
        if edges ~= .Top { ret.top = 0 }
        if edges ~= .Left { ret.left = 0 }
        if edges ~= .Bottom { ret.bottom = 0 }
        if edges ~= .Right { ret.right = 0 }
        return ret
    }
    
    var horizontalInsets: UIEdgeInsets {
        return insetsByRemoving(edges: .Top | .Bottom)
    }
    
    var verticalInsets: UIEdgeInsets {
        return insetsByRemoving(edges: .Left | .Right)
    }
    
}

extension CGRect {
    
    func rectByInsetting(#insets: UIEdgeInsets) -> CGRect {
        return UIEdgeInsetsInsetRect(self, insets)
    }
    
}

// MARK: Vector arithmetic

public prefix func -(p: CGPoint) -> CGPoint {
    return CGPoint(x: -p.x, y: -p.y)
}

public prefix func -(s: CGSize) -> CGSize {
    return CGSize(width: -s.width, height: -s.height)
}

public func +(lhs:CGPoint, rhs:CGPoint) -> CGPoint {
    return CGPoint(x:lhs.x + rhs.x, y:lhs.y + rhs.y)
}

public func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint { return lhs + -rhs }

public func +(lhs: CGSize, rhs: CGSize) -> CGSize {
    return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
}

public func -(lhs: CGSize, rhs: CGSize) -> CGSize { return lhs + -rhs }

public func +=(inout lhs: CGPoint, rhs: CGPoint) { lhs = lhs + rhs }
public func -=(inout lhs: CGPoint, rhs: CGPoint) { lhs = lhs - rhs }
public func +=(inout lhs: CGSize, rhs: CGSize) { lhs = lhs + rhs }
public func -=(inout lhs: CGSize, rhs: CGSize) { lhs = lhs - rhs }

// MARK: Rects

extension CGRect {
    
    func separatorRect(#edge: CGRectEdge, thickness thick: CGFloat = 1.0) -> CGRect {
        switch (edge) {
        case .MinXEdge: return CGRect(x: minX, y: minY, width: thick, height: height)
        case .MinYEdge: return CGRect(x: minX, y: minY, width: width, height: thick)
        case .MaxXEdge: return CGRect(x: maxX - thick, y: minY, width: thick, height: height)
        case .MaxYEdge: return CGRect(x: minX, y: maxY - thick, width: width, height: thick)
        }
    }
    
    mutating func divide(atDistance: CGFloat, fromEdge edge: CGRectEdge = .MinYEdge) -> CGRect {
        let (slice, remainder) = rectsByDividing(atDistance, fromEdge: edge)
        self = remainder
        return slice
    }
    
}

// MARK: UIKit Geometry

extension UIView {
    
    var scale: CGFloat {
        let screen = window?.screen ?? UIScreen.mainScreen()
        return screen.scale
    }
    
    var hairline: CGFloat {
        return 1 / scale
    }
    
}
