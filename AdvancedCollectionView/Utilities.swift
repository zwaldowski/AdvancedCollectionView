//
//  Utilities.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

// MARK: Assertions

func assertMainThread(file: StaticString = __FILE__, line: UWord = __LINE__) {
    assert(NSThread.isMainThread(), "This code must be called on the main thread.", file: file, line: line)
}

// MARK: Bitmasks

func ~=<T where T: RawOptionSetType, T: NilLiteralConvertible>(lhs: T, rhs: T) -> Bool {
    return (lhs & rhs) != nil
}

func ~=<T where T: RawOptionSetType, T: NilLiteralConvertible>(lhs: T?, rhs: T) -> Bool {
    return lhs.map {
        $0 ~= rhs
    } ?? false
}

// MARK: Hashing

struct SimpleHash {
    
    private let prime: Int
    private(set) var result: Int
    
    init(_ initial: Int = 1, prime: Int = 31) {
        self.prime = prime
        self.result = initial
    }
    
    mutating func append<T: Hashable>(value: T) {
        let next = value.hashValue
        result = prime &* result &+ (next ^ (next >> 32))
    }
    
    mutating func append<T: Hashable>(value: T?) {
        switch value {
        case .Some(let unbox):
            append(unbox)
        default:
            append(0)
        }
    }
    
}

// MARK: Collections

func take<I: Strideable>(range: Range<I>, eachSlice slice: I.Stride) -> LazySequence<MapSequenceView<StrideTo<I>, Range<I>>> {
    return lazy(stride(from: range.startIndex, to: range.endIndex, by: slice)).map { startIndex -> Range<I> in
        let length = min(slice, startIndex.distanceTo(range.endIndex))
        let range = startIndex..<startIndex.advancedBy(length)
        return range
    }
}

func removeValue<C: RangeReplaceableCollectionType, T: Equatable where C.Generator.Element == T>(inout x: C, value: T) -> T? {
    if let index = find(x, value) {
        return x.removeAtIndex(index)
    }
    return nil
}

private func mapWithIndex<T, U, IC: CollectionType, RC: ExtensibleCollectionType where IC.Generator.Element == T, RC.Generator.Element == U, RC.Index.Distance == Int>(collection: IC, newCollection: RC.Type, transform fn: (IC.Index, T) -> U) -> RC {
    var ret = RC()
    ret.reserveCapacity(underestimateCount(collection))
    for i in collection.startIndex..<collection.endIndex {
        ret.append(fn(i, collection[i]))
    }
    return ret
}

extension Array {
    
    func mapWithIndex<U>(transform: (Array.Index, T) -> U) -> [U] {
        return AdvancedCollectionView.mapWithIndex(self, Array<U>.self, transform: transform)
    }
    
    func mapWithIndexReversed<U>(transform fn: (Array.Index, T) -> U) -> [U] {
        if isEmpty { return [] }
        
        let lastIdx = endIndex.predecessor()
        let first = fn(lastIdx, self[lastIdx])
        let range = startIndex..<lastIdx
        
        var ret = [U](count: count, repeatedValue: first)
        ret.withUnsafeMutableBufferPointer { (buf) -> () in
            for idx in lazy(range).reverse() {
                buf[idx] = fn(idx, self[idx])
            }
        }
        return ret
    }
    
}

extension Slice {
    
    func mapWithIndex<U>(transform: (Slice.Index, T) -> U) -> Slice<U> {
        return AdvancedCollectionView.mapWithIndex(self, Slice<U>.self, transform: transform)
    }
    
}

extension Dictionary {
    
    func map<NewKey, NewValue>(fn: (Key, Value) -> (NewKey, NewValue)) -> [NewKey: NewValue] {
        var d = [NewKey: NewValue](minimumCapacity: count)
        for (oldKey, oldValue) in self {
            let (newKey, newValue) = fn(oldKey, oldValue)
            d.updateValue(newValue, forKey: newKey)
        }
        return d
    }
    
}
