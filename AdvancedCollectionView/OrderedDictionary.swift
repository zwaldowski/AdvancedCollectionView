//
//  OrderedDictionary.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/29/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

public struct OrderedDictionary<Key: Hashable, Value> {
    
    typealias Keys = [Key]
    typealias Hash = [Key: Value]
    
    private(set) public var keys: Keys
    private var elements: Hash
    
    private init(keys: Keys, elements: Hash) {
        self.keys = keys
        self.elements = elements
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

extension OrderedDictionary {
    
    public init(minimumCapacity: Int) {
        var keys = Keys()
        keys.reserveCapacity(minimumCapacity)
        self.init(keys: keys, elements: Hash(minimumCapacity: minimumCapacity))
    }
    
    public init() {
        self.init(keys: Keys(), elements: [:])
    }
    
    public init<S: SequenceType where S.Generator.Element == Element>(_ sequence: S) {
        self.init()
        extend(sequence)
    }
    
    public init(element: Element) {
        self.init()
        append(element)
    }
    
}

// MARK: SequenceType

extension OrderedDictionary: SequenceType {
    
    public typealias Element = Hash.Element
    
    public func generate() -> GeneratorOf<Element> {
        let elements = self.elements
        var keysGenerator = keys.generate()
        return GeneratorOf {
            if let nextKey = keysGenerator.next() {
                let value = elements[nextKey]!
                return (nextKey, value)
            }
            return nil
        }
    }
    
}

// MARK: CollectionType

extension OrderedDictionary: CollectionType {
    
    public typealias Index = Keys.Index
    
    public var startIndex: Index { return keys.startIndex }
    public var endIndex: Index { return keys.endIndex }
    
    /// Gets or sets existing entries in an ordered dictionary by index. If the key exists, its entry will be deleted before the new entry is inserted; the insertion compensates for the deleted key.
    public subscript(index: Index) -> Element {
        let key = keys[index]
        let value = elements[key]!
        return (key, value)
    }
    
    public subscript(key: Key) -> Value? {
        get {
            return elements[key]
        }

        mutating set(newValue) {
            if let newValue = newValue {
                _ = updateValue(newValue, forKey: key)
            } else {
                _ = removeValueForKey(key)
            }
        }
    }
    
    /// Gets a subrange of existing keys in an ordered dictionary using square bracket subscripting with an integer range.*/
    public subscript(#keyRange: Range<Index>) -> Slice<Key> {
        return keys[keyRange]
    }
    
}

// MARK: ExtensibleCollectionType

extension OrderedDictionary: ExtensibleCollectionType {
    
    public mutating func reserveCapacity(n: Int) {
        keys.reserveCapacity(n)
    }
    
    public mutating func extend<S: SequenceType where S.Generator.Element == Element>(newElements: S) {
        let asSeq = SequenceOf<Element>(newElements)

        reserveCapacity(countElements(keys) + underestimateCount(asSeq))

        for el in asSeq {
            append(el)
        }
    }
    
    public mutating func append(element: Element) {
        if elements.updateValue(element.1, forKey: element.0) == nil {
            keys.append(element.0)
        }
    }
    
}

// MARK: RangeReplaceableCollectionType

extension OrderedDictionary: RangeReplaceableCollectionType {
    
    /// Replace the given `subRange` of elements with `newElements`.
    public mutating func replaceRange<C : CollectionType where C.Generator.Element == Element>(subRange: Range<Index>, with newElements: C) {
        removeRange(subRange)
        splice(newElements, atIndex: subRange.startIndex)
    }
    
    /// Inserts an entry into the collection at a given index. If the key exists, its entry will be deleted before the new entry is inserted; the insertion compensates for the deleted key.
    public mutating func insert(newElement: Element, atIndex i: Index) {
        if let oldValue = elements[newElement.0] {
            if let keyIndex = find(keys, newElement.0) {
                let idx = i > keyIndex ? i - 1 : i
                keys.removeAtIndex(keyIndex)
                elements[newElement.0] = newElement.1
                keys.insert(newElement.0, atIndex: idx)
            }
        } else {
            keys.insert(newElement.0, atIndex: i)
            elements[newElement.0] = newElement.1
        }
    }
    
    /// Insert `newElements` at index `i`
    public mutating func splice<S : CollectionType where S.Generator.Element == Element>(newElements: S, atIndex i: Index) {
        Swift.splice(&self, [Element](newElements), atIndex: i)
    }
    
    /// Removes the entry at the given index and returns it.
    public mutating func removeAtIndex(i: Index) -> Element {
        let key = keys[i]
        let value = elements.removeValueForKey(key)!
        keys.removeAtIndex(i)
        return (key, value)
    }
    
    /// Remove the indicated `subRange` of elements
    public mutating func removeRange(subRange: Range<Index>) {
        Swift.removeRange(&self, subRange)
    }
    
    /// Removes all the elements from the collection and clears the underlying storage buffer.
    public mutating func removeAll(keepCapacity: Bool = false) {
        keys.removeAll(keepCapacity: keepCapacity)
        elements.removeAll(keepCapacity: keepCapacity)
    }
    
}

// MARK: Printable

extension OrderedDictionary: Printable {
    
    public var description: String {
        let str = lazy(self).map(toString)
        return "[\(str)]"
    }
    
}

// MARK: Extra

extension OrderedDictionary {
    
    // MARK: Convenience
    
    public var values: LazyBidirectionalCollection<MapCollectionView<OrderedDictionary<Key, Value>, Value>> {
        return lazy(self).map { $0.1 }
    }
    
    
    // MARK: Updating
    
    /// Inserts at the end or updates a value for a given key and returns the previous value for that key if one existed, or nil if a previous value did not exist.
    mutating func updateValue(value: Value, forKey key: Key) -> Value? {
        let ret = elements.updateValue(value, forKey: key)
        if ret == nil {
            keys.append(key)
        }
        return ret
    }
    
    // MARK: Removing
    
    /// Removes the key-value pair for the specified key and returns its value, or nil if a value for that key did not previously exist.*/
    mutating func removeValueForKey(key: Key) -> Value? {
        if let ret = elements.removeValueForKey(key) {
            removeValue(&keys, key)
            return ret
        }
        return nil
    }
    
    // MARK: Sorting

    /// Sorts the receiver in place using a given closure to determine the order of a provided pair of elements.
    mutating func sort(isOrderedBefore sortFunction: (Element, Element) -> Bool) {
        keys = Keys(Swift.sorted(self, sortFunction).map { $0.0 })
    }
    
    /// Sorts the receiver in place using a given closure to determine the order of a provided pair of elements by their keys.
    mutating func sortKeys(keyIsOrderedBefore sortFunction: (Key, Key) -> Bool) {
        keys.sort(sortFunction)
    }
    
}
