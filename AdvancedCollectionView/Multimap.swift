//
//  Multimap.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/18/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

public struct Multimap<K: Hashable, V> {
    
    private typealias Hash = [K: [V]]
    private typealias Group = Hash.Element
    
    private var elements: Hash
    private init(_ elements: Hash) {
        self.elements = elements
    }
    
}

// MARK: Initializers

extension Multimap: DictionaryLiteralConvertible {
    
    public typealias Key = K
    public typealias Value = [V]
    
    public init() {
        self.init([:])
    }
    
    public init<S: SequenceType where S.Generator.Element == Group>(groups: S) {
        self.init()
        extend(groups: groups)
    }
    
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(groups: elements)
    }
    
}

// MARK: Accessors

extension Multimap {
    
    public var count: Int {
        return Swift.reduce(lazy(elements).map { $0.1.count }, 0, +)
    }
    
    public var isEmpty: Bool {
        for (_, array) in elements {
            if !array.isEmpty {
                return false
            }
        }
        return true
    }
    
    public subscript(i: K) -> [V] {
        get { return elements[i] ?? [] }
        set(newValue) {
            if newValue.isEmpty {
                elements.removeValueForKey(i)
            } else {
                elements[i] = newValue
            }
        }
    }
    
    public subscript(key: K, index: Value.Index) -> V? {
        return elements[key]?[index]
    }
    
    public func contains(key: K) -> Bool {
        return elements.indexForKey(key) != nil
    }
    
}

// MARK: Mutators

extension Multimap {
    
    private mutating func mutate(arrayForKey key: K, transform: (inout array: Value) -> (), replace: (() -> Value)? = nil) {
        if var newArr = elements[key] {
            transform(array: &newArr)
            self[key] = newArr
        } else if let replace = replace {
            self[key] = replace()
        }
    }
    
    public mutating func remove(fromKey key: K, atIndex index: Value.Index) {
        mutate(arrayForKey: key, transform: { (inout array: Value) in
            _ = array.removeAtIndex(index)
        }, replace: nil)
    }
    
    public mutating func remove(valuesForKey key: K) -> Value? {
        return elements.removeValueForKey(key)
    }
    
    public mutating func removeAll(keepCapacity: Bool = false) {
        elements.removeAll(keepCapacity: keepCapacity)
    }
    
    public mutating func update<S: SequenceType where S.Generator.Element == V>(values: S, forKey key: K) -> Value? {
        var generator = values.generate()
        if let first: V = generator.next() {
            var array = [ first ]
            array.extend(SequenceOf { generator })
            return elements.updateValue(array, forKey: key)
        } else {
            if let index = elements.indexForKey(key) {
                let ret = elements[index].1
                elements.removeAtIndex(index)
                return ret
            } else {
                return nil
            }
        }
    }
    
    public mutating func append(newElement: V, forKey key: K) {
        mutate(arrayForKey: key, transform: { (inout array: Value) in
            array.append(newElement)
        }, replace: {
            [ newElement ]
        })
    }
    
    public mutating func insert(newElement: V, forKey key: K, atIndex index: Value.Index) {
        mutate(arrayForKey: key, transform: { (inout array: Value) in
            array.insert(newElement, atIndex: index)
        }, replace: {
            [ newElement ]
        })
    }
    
    public mutating func extend<Seq: SequenceType where Seq.Generator.Element == V>(#values: Seq, forKey key: K) {
        mutate(arrayForKey: key, transform: { (inout array: Value) in
            array.extend(values)
        }, replace: {
            Array(values)
        })
    }
    
    public mutating func extend<S: SequenceType where S.Generator.Element == Group>(groups newElements: S) {
        for entry in SequenceOf<Group>(newElements) {
            mutate(arrayForKey: entry.0, transform: { (inout array: Value) in
                array.extend(entry.1)
            }, replace: {
                entry.1
            })
        }
    }
    
}

// MARK: SequenceType

extension Multimap: SequenceType {
    
    public func generate() -> MultimapGenerator<K, V> {
        return MultimapGenerator(elements)
    }
    
    public func enumerate(forKey key: K) -> SequenceOf<(K, Int, V)> {
        if let index = elements.indexForKey(key) {
            let gen = MultimapEnumerateGenerator(CollectionOfOne(elements[index]))
            return SequenceOf { gen }
        } else {
            return SequenceOf(EmptyCollection())
        }
    }
    
    public func groups(includeGroup fn: (Group -> Bool)? = nil) -> SequenceOf<Group> {
        if let fn = fn {
            return SequenceOf(lazy(elements).filter(fn))
        }
        return SequenceOf(elements)
    }
    
    public mutating func updateMap(groupForKey key: K, transform: V -> V) {
        mutate(arrayForKey: key, transform: { (inout array: Value) in
            array = array.map(transform)
        }, replace: nil)
    }
    
    public mutating func updateMapWithIndex(groupForKey key: K, transform: (Int, V) -> V) {
        mutate(arrayForKey: key, transform: { (inout array: Value) in
            array = array.mapWithIndex(transform)
        }, replace: nil)
    }
    
}


// MARK: Generators

public struct MultimapEnumerateGenerator<K: Hashable, V>: GeneratorType {
    
    public typealias Element = (K, Int, V)
    public typealias Group = (K, [V])
    
    private var outerGenerator: GeneratorOf<Group>
    private var outerKey: K?
    private var innerGenerator: EnumerateGenerator<IndexingGenerator<[V]>>?
    
    public init<S: SequenceType where S.Generator.Element == Group>(_ seq: S) {
        self.outerGenerator = GeneratorOf(seq.generate())
    }
    
    public mutating func next() -> Element? {
        if let (index, value) = innerGenerator?.next() {
            return (outerKey!, index, value)
        }
        
        if let (key, array) = outerGenerator.next() {
            outerKey = key
            innerGenerator = enumerate(array).generate()
            return next()
        }
        
        return nil
    }
    
}

public struct MultimapGenerator<K: Hashable, V>: GeneratorType {
    
    public typealias Element = (K, V)
    public typealias Group = (K, [V])
    
    private var outerGenerator: GeneratorOf<Group>
    private var outerKey: K?
    private var innerGenerator: IndexingGenerator<[V]>?
    
    private init<S: SequenceType where S.Generator.Element == Group>(_ seq: S) {
        self.outerGenerator = GeneratorOf(seq.generate())
    }
    
    public mutating func next() -> Element? {
        if let value = innerGenerator?.next() {
            return (outerKey!,  value)
        }
        
        if let (key, array) = outerGenerator.next() {
            outerKey = key
            innerGenerator = array.generate()
            return next()
        }
        
        return nil
    }
    
}
