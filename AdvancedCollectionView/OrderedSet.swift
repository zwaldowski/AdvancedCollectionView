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

// MARK: ExtensibleCollectionType

extension OrderedSet: ExtensibleCollectionType {
    
    public mutating func reserveCapacity(n: Index.Distance) {
        ordered.reserveCapacity(n)
    }
    
    public mutating func extend<S: SequenceType where S.Generator.Element == T>(newElements: S) {
        let asSeq = SequenceOf<T>(newElements)
        
        ordered.reserveCapacity(ordered.count + underestimateCount(asSeq))
        
        for el in asSeq {
            insert(el)
        }
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
        elements -= oldOrdered
        elements.extend(newElements)
    }
    
    /// Insert `newElement` at index `i`.
    public mutating func insert(newElement: T, atIndex i: Index) {
        if elements.insert(newElement) {
            ordered.insert(newElement, atIndex: i)
        }
    }
    
    /// Insert `newElements` at index `i`
    public mutating func splice<S: CollectionType where S.Generator.Element == T>(newElements: S, atIndex i: Index) {
        ordered.splice(newElements, atIndex: i)
        elements += newElements
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

// MARK: UnorderedCollectionType

extension OrderedSet: UnorderedCollectionType {
    
    public func contains(element: T) -> Bool {
        return elements.contains(element)
    }
    
    public mutating func insert(element: T) -> Bool {
        if elements.insert(element) {
            ordered.append(element)
            return true
        }
        return false
    }
    
    public mutating func remove(element: T) -> Bool {
        if elements.remove(element) {
            for (idx, value) in enumerate(ordered) {
                if value != element { continue }
                
                ordered.removeAtIndex(idx)
                return true
            }
        }
        return false
    }
    
    public mutating func intersect<S: UnorderedCollectionType where S.Generator.Element == T>(set: S) {
        for element in self {
            if !set.contains(element) {
                remove(element)
            }
        }
    }
    
    public mutating func difference<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) {
        for element in SequenceOf<T>(sequence) {
            remove(element)
        }
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
        return elements.reduce(initial, combine: combine)
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
