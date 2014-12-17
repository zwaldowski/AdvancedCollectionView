//
//  Geometry.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import CoreGraphics
import UIKit.UIGeometry
import Swift

// MARK: Rounding

public protocol Scalable: FloatingPointType, FloatLiteralConvertible {
    func *(lhs: Self, rhs: Self) -> Self
    func /(lhs: Self, rhs: Self) -> Self
}

extension Double: Scalable {}
extension CGFloat: Scalable {}

private func rround<T: Scalable>(value: T, scale: T = 1.0, function: T -> T) -> T {
    return (scale > T(1)) ? (function(value * scale) / scale) : function(value)
}

// MARK: Approximate equality for UI purposes

public protocol ApproximatelyEquatable: AbsoluteValuable, Comparable {
    class var accuracy: Self { get }
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

@transparent public func ~== <T: ApproximatelyEquatable>(lhs: T, rhs: T) -> Bool {
    return T.abs(rhs - lhs) <= T.accuracy
}

@transparent public func !~== <T: ApproximatelyEquatable>(lhs: T, rhs: T) -> Bool {
    return !(lhs ~== rhs)
}

// MARK: Edge insets

@transparent public func ==(lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> Bool {
    return UIEdgeInsetsEqualToEdgeInsets(lhs, rhs)
}

extension UIEdgeInsets: Equatable {
    
    func without(edges: UIRectEdge) -> UIEdgeInsets {
        var ret = self
        if contains(edges, .Top) { ret.top = 0 }
        if contains(edges, .Left) { ret.left = 0 }
        if contains(edges, .Bottom) { ret.bottom = 0 }
        if contains(edges, .Right) { ret.right = 0 }
        return ret
    }
    
}

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
    
}

// MARK: Arithmetic

public prefix func -(p: CGPoint) -> CGPoint {
    return CGPoint(x: -p.x, y: -p.y)
}

public prefix func -(t: CGAffineTransform) -> CGAffineTransform {
    return CGAffineTransformInvert(t)
}

public func +(lhs: CGAffineTransform, rhs: CGAffineTransform) -> CGAffineTransform {
    return CGAffineTransformConcat(lhs, rhs)
}

public func -(lhs: CGAffineTransform, rhs: CGAffineTransform) -> CGAffineTransform {
    return lhs + -rhs
}

public prefix func -(t: CATransform3D) -> CATransform3D {
    return CATransform3DInvert(t)
}

public func +(lhs: CATransform3D, rhs: CATransform3D) -> CATransform3D {
    return CATransform3DConcat(lhs, rhs)
}

public func -(lhs: CATransform3D, rhs: CATransform3D) -> CATransform3D {
    return lhs + -rhs
}

public func += (inout lhs: CGAffineTransform, rhs: CGAffineTransform) { lhs = lhs + rhs }
public func -= (inout lhs: CGAffineTransform, rhs: CGAffineTransform) { lhs = lhs - rhs }
public func += (inout lhs: CATransform3D, rhs: CATransform3D) { lhs = lhs + rhs }
public func -= (inout lhs: CATransform3D, rhs: CATransform3D) { lhs = lhs - rhs }

// MARK: Vector arithmetic

public func +(lhs:CGPoint, rhs:CGPoint) -> CGPoint {
    return CGPoint(x:lhs.x + rhs.x, y:lhs.y + rhs.y)
}

public func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

public func +=(inout lhs: CGPoint, rhs: CGPoint) { lhs = lhs + rhs }
public func -=(inout lhs: CGPoint, rhs: CGPoint) { lhs = lhs - rhs }

// MARK: Equatability

public func ==(lhs: CGAffineTransform, rhs: CGAffineTransform) -> Bool {
    return CGAffineTransformEqualToTransform(lhs, rhs)
}

public func ==(lhs: CATransform3D, rhs: CATransform3D) -> Bool {
    return CATransform3DEqualToTransform(lhs, rhs)
}

extension CGAffineTransform: Equatable { }
extension CATransform3D: Equatable { }
