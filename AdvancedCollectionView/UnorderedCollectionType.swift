//
//  UnorderedCollectionType.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/27/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

public protocol UnorderedCollectionType: ExtensibleCollectionType, Equatable, ArrayLiteralConvertible {
    
    // MARK: Properties
    
    /// The number of entries in the set.
    var count: Int { get }
    
    /// True iff `count == 0`
    var isEmpty: Bool { get }
    
    // MARK: Constructors
    
    /// Constructs the empty set.
    init()
    
    /// Constructs a set with a hint as to the capacity it should allocate.
    init(minimumCapacity: Int)
    
    /// Constructs a set with the elements of `sequence`.
    init<S: SequenceType where S.Generator.Element == Self.Generator.Element>(_ sequence: S)
    
    /// Constructs a set with given `element`.
    init(_ element: Self.Generator.Element...)
    
    // MARK: Primitives
    
    /// True iff `element` is in the receiver, as defined by its hash and equality.
    func contains(element: Self.Generator.Element) -> Bool
    
    /// Inserts `element` into the receiver, if it doesn’t already exist.
    mutating func insert(element: Element) -> Bool
    
    /// Removes `element` from the receiver, if it’s a member.
    mutating func remove(element: Element) -> Bool
    
    // MARK: Algebraic operations
    
    /// Remove all elements from the receiver which are not contained in `set`.
    mutating func intersect<S: UnorderedCollectionType where S.Generator.Element == Self.Generator.Element>(set: S)
    
    /// Remove all elements from the receiver which are contained in `set`.
    mutating func difference<Seq: SequenceType where Seq.Generator.Element == Self.Generator.Element>(sequence: Seq)

}

// MARK: - Free functions

/// True iff the receiver is a subset of (is included in) `set`.
public func subset<S1: UnorderedCollectionType, S2: UnorderedCollectionType where S1.Generator.Element == S2.Generator.Element>(a1: S1, a2: S2) -> Bool {
    for el in a1 {
        if !a2.contains(el) { return false }
    }
    return true
}

/// True iff the receiver is a superset of (includes) `set`.
public func superset<S1: UnorderedCollectionType, S2: UnorderedCollectionType where S1.Generator.Element == S2.Generator.Element>(a1: S1, a2: S2) -> Bool {
    return subset(a2, a1)
}

// MARK: - Operators

// Extends a `set` with the elements of a `sequence`.
public func +=<Set: UnorderedCollectionType, Seq: SequenceType where Set.Generator.Element == Seq.Generator.Element>(inout set: Set, sequence: Seq) {
    set.extend(sequence)
}

/// Returns a new set with all elements from the left-hand set which are not contained in the right-hand set.
public func -<S1: UnorderedCollectionType, S2: UnorderedCollectionType where S1.Generator.Element == S2.Generator.Element>(lhs: S1, rhs: S2) -> S1 {
    return S1(filter(lhs) {
        !rhs.contains($0)
    })
}

/// Returns a new set with all elements from the left-hand set which are not contained in the right-hand sequence.
public func -<S: UnorderedCollectionType, Seq: SequenceType where S.Generator.Element == Seq.Generator.Element>(lhs: S, rhs: Seq) -> S {
    var ret = lhs
    ret.difference(rhs)
    return ret
}

/// Remove all elements on the right-hand side from the set on the left-hand side.
public func -=<S: UnorderedCollectionType, Seq: SequenceType where Seq.Generator.Element == S.Generator.Element>(inout lhs: S, rhs: Seq) {
    lhs.difference(rhs)
}

/// Returns the intersection of `set` and `other`.
public func &<S1: UnorderedCollectionType, S2: UnorderedCollectionType where S1.Generator.Element == S2.Generator.Element>(lhs: S1, rhs: S2) -> S1 {
    if lhs.count <= rhs.count {
        return S1(lazy(lhs).filter { rhs.contains($0) })
    } else {
        return S1(lazy(rhs).filter { lhs.contains($0) })
    }
}

/// Itersects with `set` with `other`.
public func &=<S1: UnorderedCollectionType, S2: UnorderedCollectionType where S1.Generator.Element == S2.Generator.Element>(inout lhs: S1, rhs: S2) {
    lhs.intersect(rhs)
}
