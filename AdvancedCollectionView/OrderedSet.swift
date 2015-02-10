//
//  OrderedSet.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/27/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

public struct OrderedSet<T: Hashable> {
    
    public typealias Unordered = Set<T>
    public typealias Ordered = [T]
    
    private(set) public var elements: Unordered
    private(set) public var ordered: Ordered
    
    private init(elements: Unordered, ordered: Ordered) {
        self.elements = elements
        self.ordered = ordered
    }
    
    // MARK: Properties
    
    /// The number of entries in the set.
    public var count: Int { return elements.count }
    
    /// True iff `count == 0`
    public var isEmpty: Bool {
        return elements.isEmpty
    }
    
}

// MARK: Constructors

extension OrderedSet {
    
    public init(minimumCapacity: Int) {
        var array = [T]()
        array.reserveCapacity(minimumCapacity)
        self.init(elements: Set(minimumCapacity: minimumCapacity), ordered: array)
    }
    
    public init() {
        self.init(minimumCapacity: 2)
    }
    
    public init<S: SequenceType where S.Generator.Element == T>(_ sequence: S) {
        self.init()
        extend(sequence)
    }
    
    public init(_ elements: T...) {
        self.init(elements)
    }
    
}

// MARK: SequenceType

extension OrderedSet: SequenceType {
    
    public func generate() -> GeneratorOf<T> {
        return GeneratorOf(ordered.generate())
    }
    
}

// MARK: CollectionType

extension OrderedSet: CollectionType {
    
    public typealias Index = Ordered.Index
    
    public var startIndex: Index { return ordered.startIndex }
    public var endIndex: Index { return ordered.endIndex }
    
    public subscript(index: Index) -> T {
        return ordered[index]
    }
    
}

// MARK: Set

extension OrderedSet {
    
    public func contains(element: T) -> Bool {
        return elements.contains(element)
    }
    
    public mutating func insert(element: T) {
        if elements.contains(element) { return }
        elements.insert(element)
        ordered.append(element)
    }
    
    public mutating func remove(element: T) -> T? {
        if let el = elements.remove(element) {
            for (idx, value) in enumerate(ordered) {
                if value != el { continue }
                
                ordered.removeAtIndex(idx)
                return el
            }
        }
        return nil
    }
    
    /// A member of the set, or `nil` if the set is empty.
    public var first: T? {
        return ordered.first
    }
    
    /// Returns true if the set is a subset of a finite sequence as a `Set`.
    public func isSubsetOf<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) -> Bool {
        return elements.isSubsetOf(sequence)
    }
    
    /// Returns true if the set is a subset of a finite sequence as a `Set`
    /// but not equal.
    public func isStrictSubsetOf<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) -> Bool {
        return elements.isStrictSubsetOf(sequence)
    }
    
    /// Returns true if the set is a superset of a finite sequence as a `Set`.
    public func isSupersetOf<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) -> Bool {
        return elements.isSupersetOf(sequence)
    }
    
    /// Returns true if the set is a superset of a finite sequence as a `Set`
    /// but not equal.
    public func isStrictSupersetOf<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) -> Bool {
        return elements.isStrictSupersetOf(sequence)
    }
    
    /// Returns true if no members in the set are in a finite sequence as a `Set`.
    public func isDisjointWith<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) -> Bool {
        return elements.isDisjointWith(sequence)
    }
    
    public func union<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) -> OrderedSet<T> {
        let newSet = elements.union(sequence)
        var newArray = ordered
        newArray.reserveCapacity(newSet.count)
        for el in sequence {
            if !elements.contains(el) {
                newArray.append(el)
            }
        }
        return OrderedSet(elements: newSet, ordered: newArray)
    }
    
    public mutating func unionInPlace<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) {
        ordered.reserveCapacity(ordered.count + underestimateCount(sequence))
        for el in sequence {
            insert(el)
        }
    }
    
    public func subtract<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) -> OrderedSet<T> {
        let newSet = elements.subtract(sequence)
        let newArray = ordered.filter {
            newSet.contains($0)
        }
        return OrderedSet(elements: newSet, ordered: newArray)
    }
    
    public mutating func subtractInPlace<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) {
        elements.subtractInPlace(sequence)
        ordered = ordered.filter {
            self.elements.contains($0)
        }
    }
    
    public func intersect<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) -> OrderedSet<T> {
        let newSet = elements.intersect(sequence)
        let newArray = ordered.filter {
            newSet.contains($0)
        }
        return OrderedSet(elements: newSet, ordered: newArray)
    }
    
    public mutating func intersectInPlace<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) {
        elements.intersectInPlace(sequence)
        ordered = ordered.filter {
            self.elements.contains($0)
        }
    }
    
}

// MARK: ExtensibleCollectionType

extension OrderedSet: ExtensibleCollectionType {
    
    public mutating func reserveCapacity(n: Index.Distance) {
        ordered.reserveCapacity(n)
    }
    
    public mutating func extend<S: SequenceType where S.Generator.Element == T>(newElements: S) {
        unionInPlace(newElements)
    }
    
    public mutating func append(element: T) {
        insert(element)
    }
    
}

// MARK: RangeReplaceableCollectionType

extension OrderedSet: RangeReplaceableCollectionType {
    
    /// Replace the given `subRange` of elements with `newElements`.
    public mutating func replaceRange<C : CollectionType where C.Generator.Element == T>(subRange: Range<Index>, with newElements: C) {
        let oldOrdered = ordered[subRange]
        ordered.replaceRange(subRange, with: newElements)
        elements.subtractInPlace(oldOrdered)
        elements.unionInPlace(newElements)
    }
    
    /// Insert `newElement` at index `i`.
    public mutating func insert(newElement: T, atIndex i: Index) {
        if elements.contains(newElement) { return }
        elements.insert(newElement)
        ordered.insert(newElement, atIndex: i)
    }
    
    /// Insert `newElements` at index `i`
    public mutating func splice<S: CollectionType where S.Generator.Element == T>(newElements: S, atIndex i: Index) {
        ordered.splice(newElements, atIndex: i)
        elements.unionInPlace(newElements)
    }
    
    /// Remove the element at index `i`.
    public mutating func removeAtIndex(i: Index) -> T {
        let el = ordered.removeAtIndex(i)
        elements.remove(el)
        return el
    }
    
    /// Remove the indicated `subRange` of elements
    public mutating func removeRange(subRange: Range<Index>) {
        Swift.removeRange(&self, subRange)
    }
    
    /// Removes all elements from the receiver.
    public mutating func removeAll(keepCapacity: Bool = false) {
        elements.removeAll(keepCapacity: keepCapacity)
        ordered.removeAll(keepCapacity: keepCapacity)
    }
    
}

// MARK: Equatable

public func ==<T>(a: OrderedSet<T>, b: OrderedSet<T>) -> Bool {
    return a.ordered == b.ordered
}

extension OrderedSet: Equatable { }

// MARK: ArrayLiteralConvertible

extension OrderedSet: ArrayLiteralConvertible {
    
    public init(arrayLiteral elements: T...) {
        self.init(elements)
    }
    
}

// MARK: Printable

extension OrderedSet: Printable, DebugPrintable {
    
    public var description: String {
        return ordered.description
    }
    
    public var debugDescription: String {
        return ordered.debugDescription
    }
    
}

// MARK: Reflectable

extension OrderedSet: Reflectable {
    
    public func getMirror() -> MirrorType {
        return ordered.getMirror()
    }
}

// MARK: Functional

extension OrderedSet {
    
    public func reduce<U>(initial: U, combine: (U, T) -> U) -> U {
        return Swift.reduce(elements, initial, combine)
    }
    
    public mutating func sort(isOrderedBefore function: (T, T) -> Bool) {
        ordered.sort(function)
    }
    
    public mutating func sorted(isOrderedBefore function: (T, T) -> Bool) -> OrderedSet<T> {
        let newArray = ordered.sorted(function)
        return OrderedSet(elements: elements, ordered: newArray)
    }
    
    public func map<U>(transform: T -> U) -> OrderedSet<U> {
        let newArray = ordered.map(transform)
        return OrderedSet<U>(elements: Set(newArray), ordered: newArray)
    }

    public func reverse() -> OrderedSet<T> {
        return OrderedSet(elements: elements, ordered: ordered.reverse())
    }
    
    public func filter(includeElement: T -> Bool) -> OrderedSet<T> {
        let newArray = ordered.filter(includeElement)
        return OrderedSet(elements: Set(newArray), ordered: newArray)
    }
    
}

// MARK: Unsafe access

extension OrderedSet {
    
    public func withUnsafeBufferPointer<R>(body: (UnsafeBufferPointer<T>) -> R) -> R {
        return ordered.withUnsafeBufferPointer(body)
    }
    
}
