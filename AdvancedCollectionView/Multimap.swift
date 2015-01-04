//
//  Multimap.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/18/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

public struct Multimap<Key: Hashable, Value> {
    
    typealias Values = [Value]
    typealias Group = (key: Key, array: Values)
    private typealias Groups = [Key: Values]
    private typealias GroupIndex = DictionaryIndex<Key, Values>
    
    private var map = Groups()
    
    private init(map: Groups) {
        self.map = map
    }
    
}

// MARK: Initializers

extension Multimap: DictionaryLiteralConvertible {
    
    public init(){}
    
    public init<S: SequenceType where S.Generator.Element == Group>(groups: S) {
        for entry in [Group](groups) {
            map[entry.key] = entry.array
        }
    }
    
    public init(dictionaryLiteral elements: (Key, Values)...) {
        self.init(groups: elements)
    }
    
}

// MARK: Accessors

extension Multimap {
    
    public var count: Int {
        return Swift.reduce(lazy(map).map { $0.1.count }, 0, +)
    }
    
    public var isEmpty: Bool {
        return map.count == 0 || self.count == 0
    }
    
    public subscript(i: Key) -> Values {
        get { return map[i] ?? [] }
        set(newValue) { map[i] = newValue }
    }
    
    public subscript(key: Key, index: Values.Index) -> Value? {
        return map[key]?[index]
    }
    
    public func contains(key: Key) -> Bool {
        return map.indexForKey(key) != nil
    }
    
}

// MARK: Mutators

extension Multimap {
    
    private mutating func mutate(arrayForKey key: Key, transform: (inout array: Values) -> (), replace: (() -> Values)? = nil) {
        var newArr: Values!
        if var newArr = map[key] {
            transform(array: &newArr)
        } else if let replace = replace {
            newArr = replace()
        } else {
            return
        }
        
        if newArr.count > 0 {
            map[key] = newArr
        } else {
            map.removeValueForKey(key)
        }
    }
    
    public mutating func remove(fromKey key: Key, atIndex index: Values.Index) {
        mutate(arrayForKey: key) { (inout array: Values) in
            _ = array.removeAtIndex(index)
        }
    }
    
    public mutating func remove(valuesForKey key: Key) -> Values? {
        return map.removeValueForKey(key)
    }
    
    public mutating func removeAll(keepCapacity: Bool = false) {
        map.removeAll(keepCapacity: keepCapacity)
    }
    
    public mutating func update<S: SequenceType where S.Generator.Element == Value>(values: S, forKey key: Key) -> Values? {
        return map.updateValue(Array(values), forKey: key)
    }
    
    public mutating func append(newElement: Value, forKey key: Key) {
        mutate(arrayForKey: key, transform: { (inout array: Values) in
            array.append(newElement)
        }, replace: {
            [ newElement ]
        })
    }
    
    public mutating func insert(newElement: Value, forKey key: Key, atIndex index: Values.Index) {
        mutate(arrayForKey: key, transform: { (inout array: Values) in
            array.insert(newElement, atIndex: index)
        }, replace: {
            [ newElement ]
        })
    }
    
    public mutating func extend<Seq: SequenceType where Seq.Generator.Element == Value>(#values: Seq, forKey key: Key) {
        mutate(arrayForKey: key, transform: { (inout array: Values) in
            array.extend(values)
        }, replace: {
            Array(values)
        })
    }
    
    public mutating func extend<S: SequenceType where S.Generator.Element == Group>(groups newElements: S) {
        for entry in SequenceOf<Group>(newElements) {
            mutate(arrayForKey: entry.key, transform: { (inout array: Values) in
                array.extend(entry.array)
            }, replace: {
                entry.array
            })
        }
    }
    
}

// MARK: Generators

public struct MultimapGenerator<K: Hashable, V>: GeneratorType {
    
    private typealias Parent = Multimap<K, V>
    private var outerGenerator: GeneratorOf<Parent.Group>?
    private var outerKey: K!
    private var innerGenerator: EnumerateGenerator<IndexingGenerator<Parent.Values>>?
    private let filter: Parent.ElementFilter
    
    private init(_ seq: SequenceOf<Parent.Group>, filter: Parent.ElementFilter? = nil) {
        var outer = seq.generate()
        if let el: Parent.Group = outer.next() {
            self.outerGenerator = outer
            self.outerKey = el.key
            self.innerGenerator = enumerate(el.array).generate()
        }
        
        if let filter = filter {
            self.filter = filter
        } else {
            self.filter = { _ in true }
        }
    }
    
    private mutating func _next() -> Parent.Element? {
        if let (index, value) = innerGenerator?.next() {
            return (outerKey, index, value)
        }
        
        if let (key, array) = outerGenerator?.next() {
            outerKey = key
            innerGenerator = enumerate(array).generate()
            return _next()
        }
        
        return nil
    }
    
    public mutating func next() -> Parent.Element? {
        while let next = _next() {
            if filter(next) { return next }
        }
        return nil
    }
    
}

public struct MultimapSequence<K: Hashable, V>: SequenceType {
    
    private typealias Parent = Multimap<K, V>
    private let base: SequenceOf<Parent.Group>
    private let filter: Parent.ElementFilter?
    
    private init(_ seq: SequenceOf<Parent.Group>, filter: Parent.ElementFilter?) {
        self.base = seq
        self.filter = filter
    }
    
    private init() {
        self.init(SequenceOf { GeneratorOf { nil } })
    }
    
    public init(group: Parent.Group) {
        self.init(SequenceOf(CollectionOfOne(group)))
    }

    public init<S: SequenceType where S.Generator.Element == Parent.Group>(_ seq: S) {
        self.init(SequenceOf(seq), filter: nil)
    }
    
    public func generate() -> MultimapGenerator<K, V> {
        return MultimapGenerator(base, filter)
    }

    public func map<U>(transform: Parent.Element -> U) -> [U] {
        return Swift.map(self, transform)
    }
    
    public func filter(includeGroup fn: Parent.Group -> Bool) -> MultimapSequence<K, V> {
        return MultimapSequence(lazy(base).filter(fn))
    }
    
    public func filter(includeElement fn: Parent.Element -> Bool) -> MultimapSequence<K, V> {
        if let filter = filter {
            return MultimapSequence(base, {
                filter($0) && fn($0)
            })
        }
        return MultimapSequence(base, fn)
    }
    
    public func reduce<U>(initial: U, combine: (U, Parent.Element) -> U) -> U {
        return Swift.reduce(self, initial, combine)
    }
    
}

extension Multimap: SequenceType {
    
    public typealias Sequence = MultimapSequence<Key, Value>
    typealias Element = (key: Key, index: Values.Index, value: Value)
    typealias ElementFilter = Element -> Bool
    
    public func generate() -> MultimapGenerator<Key, Value> {
        return MultimapGenerator(SequenceOf(map))
    }
    
    public func enumerate(forKey key: Key) -> MultimapSequence<Key, Value> {
        if let b = map.indexForKey(key) {
            return MultimapSequence(group: map[b])
        }
        return MultimapSequence()
    }
    
    public func groups(includeGroup fn: (Group -> Bool)? = nil) -> SequenceOf<Group> {
        if let fn = fn {
            return SequenceOf(lazy(map).filter(fn))
        }
        return SequenceOf(map)
    }
    
    public mutating func updateMap(groupForKey key: Key, transform: Value -> Value) {
        mutate(arrayForKey: key) { (inout array: Values) in
            array = array.map(transform)
        }
    }
    
    public mutating func updateMap(transform fn: Element -> Value) {
        map = map.map { (key, array) in
            return (key, array.mapWithIndex {
                fn((key, $0, $1))
            })
        }
    }
    
    public mutating func updateMapWithIndex(groupForKey key: Key, transform: (Values.Index, Value) -> Value) {
        mutate(arrayForKey: key) { (inout array: Values) in
            array = array.mapWithIndex(transform)
        }
    }
    
    public func filter(includeGroup fn: Group -> Bool) -> MultimapSequence<Key, Value> {
        return MultimapSequence(groups(includeGroup: fn))
    }
    
    public func filter(includeElement fn: Element -> Bool) -> MultimapSequence<Key, Value> {
        return MultimapSequence(groups(), fn)
    }
    
    public func reduce<U>(initial: U, combine: (U, Element) -> U) -> U {
        return MultimapSequence(groups()).reduce(initial, combine: combine)
    }
    
}
