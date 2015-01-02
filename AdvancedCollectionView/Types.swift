//
//  Types.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import Foundation

public enum SectionOperationDirection {
    case Default, Left, Right
}

public struct PlaceholderContent {
    public let title: String?
    public let message: String?
    public let image: UIImage?
    
    public var isEmpty: Bool {
        switch (title, message) {
        case (.Some(let text), _):
            return !text.isEmpty
        case (.None, .Some(let text)):
            return !text.isEmpty
        default:
            return true
        }
    }
}

// MARK: Bitmasks

@transparent func contains<T where T: RawOptionSetType, T: NilLiteralConvertible>(mask: T?, bit: T) -> Bool {
    if let mask = mask {
        return (mask & bit) != nil
    }
    return false
}

// MARK: Utilities

func take<C: Sliceable where C.Index: Strideable>(collection: C, eachSlice slice: C.Index.Stride) -> LazySequence<MapSequenceView<StrideTo<C.Index>, C.SubSlice>> {
    let start = collection.startIndex
    let end = collection.endIndex
    return lazy(stride(from: start, to: end, by: slice)).map { startIndex in
        let length = min(slice, startIndex.distanceTo(end))
        let range = startIndex..<startIndex.advancedBy(length)
        return collection[range]
    }
}

func removeValue<C: RangeReplaceableCollectionType, T: Equatable where C.Generator.Element == T>(inout x: C, value: T) -> T? {
    if let index = find(x, value) {
        return x.removeAtIndex(index)
    }
    return nil
}


func mapWithIndex<T, U, C: CollectionType where C.Generator.Element == T>(collection: C, transform fn: (C.Index, T) -> U) -> [U] {
    return map(collection.startIndex..<collection.endIndex) {
        fn($0, collection[$0])
    }
}

func mapWithIndexReversed<T, U, C: CollectionType where C.Index == Int, C.Generator.Element == T>(collection: C, transform fn: (C.Index, T) -> U) -> [U] {
    let lastIdx = collection.endIndex.predecessor()
    let first = fn(lastIdx, collection[lastIdx])
    let range = collection.startIndex..<lastIdx
    
    var ret = [U](count: countElements(collection), repeatedValue: first)
    ret.withUnsafeMutableBufferPointer { (buf) -> () in
        for idx in lazy(range).reverse() {
            buf[idx] = fn(idx, collection[idx])
        }
    }
    return ret
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
