//
//  OrderedSet.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/27/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

public struct OrderedSet<Element: Hashable> {
    
    typealias Unordered = Set<Element>
    typealias Ordered = [Element]
    
    private(set) public var elements: Set<Element>
    private(set) public var ordered: [Element]
    
    private init(elements: Set<Element>, ordered: [Element]) {
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
        var array = [Element]()
        array.reserveCapacity(minimumCapacity)
        self.init(elements: Set(minimumCapacity: minimumCapacity), ordered: array)
    }
    
    public init() {
        self.init(minimumCapacity: 2)
    }
    
    public init<S: SequenceType where S.Generator.Element == Element>(_ sequence: S) {
        self.init()
        extend(sequence)
    }
    
    public init(element: Element) {
        self.init()
        append(element)
    }
    
    public init(_ array: [Element]) {
        var set = Set<Element>(minimumCapacity: array.count)
        set.extend(array)
        self.init(elements: set, ordered: array)
    }
    
}

// MARK: SequenceType

extension OrderedSet: SequenceType {
    
    public func generate() -> GeneratorOf<Element> {
        return GeneratorOf(ordered.generate())
    }
    
}

// MARK: CollectionType

extension OrderedSet: CollectionType {
    
    public var startIndex: Ordered.Index { return ordered.startIndex }
    public var endIndex: Ordered.Index { return ordered.endIndex }
    
    public subscript(index: Ordered.Index) -> Element {
        return ordered[index]
    }
    
}

// MARK: ExtensibleCollectionType

extension OrderedSet: ExtensibleCollectionType {
    
    public mutating func reserveCapacity(n: Ordered.Index.Distance) {
        ordered.reserveCapacity(n)
    }
    
    public mutating func extend<S: SequenceType where S.Generator.Element == Element>(newElements: S) {
        let asSeq = SequenceOf<Element>(newElements)
        
        ordered.reserveCapacity(countElements(ordered) + underestimateCount(asSeq))
        
        for el in asSeq {
            insert(el)
        }
    }
    
    public mutating func append(element: Element) {
        insert(element)
    }
    
}

// MARK: RangeReplaceableCollectionType

extension OrderedSet: RangeReplaceableCollectionType {
    
    /// Replace the given `subRange` of elements with `newElements`.
    public mutating func replaceRange<C : CollectionType where C.Generator.Element == Element>(subRange: Range<Ordered.Index>, with newElements: C) {
        removeRange(subRange)
        splice(newElements, atIndex: subRange.startIndex)
    }
    
    /// Insert `newElement` at index `i`.
    public mutating func insert(newElement: Element, atIndex i: Ordered.Index) {
        if elements.insert(newElement) {
            ordered.insert(newElement, atIndex: i)
        }
    }
    
    /// Insert `newElements` at index `i`
    public mutating func splice<S : CollectionType where S.Generator.Element == Element>(newElements: S, atIndex i: Ordered.Index) {
        ordered.splice(newElements, atIndex: i)
        elements += newElements
    }
    
    /// Remove the element at index `i`.
    public mutating func removeAtIndex(i: Ordered.Index) -> Element {
        let el = ordered.removeAtIndex(i)
        elements.remove(el)
        return el
    }
    
    /// Remove the indicated `subRange` of elements
    public mutating func removeRange(subRange: Range<Ordered.Index>) {
        Swift.removeRange(&self, subRange)
    }
    
    /// Removes all elements from the receiver.
    public mutating func removeAll(keepCapacity: Bool = false) {
        elements.removeAll(keepCapacity: keepCapacity)
        ordered.removeAll(keepCapacity: keepCapacity)
    }
    
}

// MARK: Equatable

public func ==<Element: Hashable>(a: OrderedSet<Element>, b: OrderedSet<Element>) -> Bool {
    return a.ordered == b.ordered
}

extension OrderedSet: Equatable { }

// MARK: ArrayLiteralConvertible

extension OrderedSet: ArrayLiteralConvertible {
    
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
    
}

// MARK: SetType

extension OrderedSet: SetType {
    
    public func contains(element: Element) -> Bool {
        return elements.contains(element)
    }
    
    public mutating func insert(element: Element) -> Bool {
        if elements.insert(element) {
            ordered.append(element)
            return true
        }
        return false
    }
    
    public mutating func remove(element: Element) -> Bool {
        if elements.remove(element) {
            for (idx, value) in enumerate(ordered) {
                if value != element { continue }
                
                ordered.removeAtIndex(idx)
                return true
            }
        }
        return false
    }
    
    public mutating func intersect<S: SetType where S.Generator.Element == Element>(set: S) {
        for element in self {
            if !set.contains(element) {
                remove(element)
            }
        }
    }
    
    public mutating func difference<Seq: SequenceType where Seq.Generator.Element == Element>(sequence: Seq) {
        for element in SequenceOf<Element>(sequence) {
            remove(element)
        }
    }
    
}

// MARK: Printable

extension OrderedSet: Printable {
    
    public var description: String {
        return ordered.description
    }
    
}

// MARK: Sorting


extension OrderedSet {
    
    public mutating func sort(isOrderedBefore function: (Element, Element) -> Bool) {
        ordered.sort(function)
    }
    
}
