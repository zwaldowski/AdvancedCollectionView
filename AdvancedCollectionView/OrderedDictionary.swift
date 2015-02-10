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
        self.init(keys: Keys(), elements: Dictionary(minimumCapacity: minimumCapacity))
        reserveCapacity(minimumCapacity)
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
        let dictionary = self.elements
        var keysGenerator = keys.generate()
        return GeneratorOf {
            if let nextKey = keysGenerator.next() {
                return dictionary.indexForKey(nextKey).map { dictionary[$0] }
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
    public subscript(i: Index) -> Element {
        let dictIndex = elements.indexForKey(keys[i])!
        return elements[dictIndex]
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
    public subscript(keyRange: Range<Index>) -> Slice<Key> {
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

        reserveCapacity(keys.count + underestimateCount(asSeq))

        for el in asSeq {
            append(el)
        }
    }
    
    public mutating func append(element: Element) {
        _ = updateValue(element.1, forKey: element.0)
    }
    
}

// MARK: RangeReplaceableCollectionType

extension OrderedDictionary: RangeReplaceableCollectionType {
    
    // Replace the given `subRange` of elements with `newElements`.
    public mutating func replaceRange<C: CollectionType where C.Generator.Element == Hash.Element>(subRange: Range<Keys.Index>, with newElements: C) {
        let oldKeys = keys[subRange]
        
        // The noise here is necessary
        let newKeys = map(newElements, { (key: Key, value: Value) -> Key in
            return key
        })
        
        keys.replaceRange(subRange, with: newKeys)
        
        for oldKey in oldKeys {
            elements.removeValueForKey(oldKey)
        }
        
        for (newKey, value) in SequenceOf<Element>(newElements) {
            elements.updateValue(value, forKey: newKey)
        }
    }
    
    /// Inserts an entry into the collection at a given index. If the key exists, its entry will be deleted before the new entry is inserted; the insertion compensates for the deleted key.
    public mutating func insert(newElement: Element, var atIndex i: Index) {
        if let indexInDict = elements.indexForKey(newElement.0) {
            if let indexInKeys = find(keys, newElement.0) {
                keys.removeAtIndex(indexInKeys)
                if i > indexInKeys {
                    i = i.predecessor()
                }
            }
        }
        
        keys.insert(newElement.0, atIndex: i)
        elements[newElement.0] = newElement.1
    }
    
    /// Insert `newElements` at index `i`
    public mutating func splice<S : CollectionType where S.Generator.Element == Element>(newElements: S, atIndex i: Index) {
        Swift.splice(&self, [Element](newElements), atIndex: i)
    }
    
    /// Removes the entry at the given index and returns it.
    public mutating func removeAtIndex(i: Index) -> Element {
        let key = keys.removeAtIndex(i)
        let value = elements.removeValueForKey(key)!
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
    
    public var values: LazyRandomAccessCollection<MapCollectionView<OrderedDictionary<Key, Value>, Value>> {
        return lazy(self).map { $0.1 }
    }
    
    
    // MARK: Updating
    
    /// Inserts at the end or updates a value for a given key and returns the previous value for that key if one existed, or nil if a previous value did not exist.
    public mutating func updateValue(value: Value, forKey key: Key) -> Value? {
        let ret = elements.updateValue(value, forKey: key)
        if ret == nil {
            keys.append(key)
        }
        return ret
    }
    
    // MARK: Removing
    
    /// Removes the key-value pair for the specified key and returns its value, or nil if a value for that key did not previously exist.*/
    public mutating func removeValueForKey(key: Key) -> Value? {
        if let ret = elements.removeValueForKey(key) {
            removeValue(&keys, key)
            return ret
        }
        return nil
    }
    
    // MARK: Sorting

    /// Sorts the receiver in place using a given closure to determine the order of a provided pair of elements.
    public mutating func sort(isOrderedBefore sortFunction: (Element, Element) -> Bool) {
        let dictionary = self.elements
        keys.sort { (key1, key2) -> Bool in
            switch (dictionary.indexForKey(key1), dictionary.indexForKey(key2)) {
            case (.Some(let el1), .Some(let el2)):
                return sortFunction(dictionary[el1], dictionary[el2])
            case (.None, .Some):
                return true
            default:
                return false
            }
        }
    }

    /// Sorts the receiver in place using a given closure to determine the order of a provided pair of elements by their keys.
    public mutating func sortKeys(keyIsOrderedBefore sortFunction: (Key, Key) -> Bool) {
        keys.sort(sortFunction)
    }
    
}
