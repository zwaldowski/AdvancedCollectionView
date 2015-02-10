//
//  Foundation.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import Foundation

// MARK: NSIndexPath

extension NSIndexPath: CollectionType {
    
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return length }
    
    public subscript (position: Int) -> Int {
        return indexAtPosition(position)
    }
    
    public func generate() -> IndexingGenerator<NSIndexPath> {
        return IndexingGenerator(self)
    }
    
}

public func ==(lhs: NSIndexPath, rhs: NSIndexPath) -> Bool {
    return lhs.isEqual(rhs)
}
public func <(lhs: NSIndexPath, rhs: NSIndexPath) -> Bool {
    return lhs.compare(rhs) == .OrderedAscending
    
}

extension NSIndexPath: Comparable { }

extension NSIndexPath {
    
    // This is intended for compatibility with ArrayLiteralConvertible
    // c'est la vie
    public convenience init(_ elements: Int...) {
        self.init(indexes: elements, length: elements.count)
    }
    
    var stringValue: String {
        let str = join(", ", lazy(self).map(toString))
        return "(\(str))"
    }
    
}

// MARK: NSIndexSet

extension NSIndexSet {
    
    public convenience init(range: Range<Int>) {
        self.init(indexesInRange: NSRange(range))
    }
    
    public convenience init(_ elements: Int...) {
        self.init(indexes: elements)
    }
    
    public convenience init<S: SequenceType where S.Generator.Element == Int>(indexes elements: S) {
        let set = NSMutableIndexSet()
        for idx in elements {
            set.addIndex(idx)
        }
        self.init(indexSet: set)
    }
    
    public func map(transform: Int -> Int) -> NSIndexSet {
        let indexSet = NSMutableIndexSet()
        for idx in self {
            indexSet.addIndex(transform(idx))
        }
        return indexSet
    }
    
    var stringValue: String {
        let str = join(", ", lazy(self).map(toString))
        return "[\(str)]"
    }
    
}

public func -=(left: NSMutableIndexSet, right: NSIndexSet) {
    left.removeIndexes(right)
}

public func +=(left: NSMutableIndexSet, right: NSIndexSet) {
    left.addIndexes(right)
}

public func -=(left: NSMutableIndexSet, right: NSRange) {
    left.removeIndexesInRange(right)
}

public func +=(left: NSMutableIndexSet, right: NSRange) {
    left.addIndexesInRange(right)
}

public func -(left: NSIndexSet, right: NSIndexSet) -> NSMutableIndexSet {
    let indexSet = left.mutableCopy() as! NSMutableIndexSet
    indexSet.removeIndexes(right)
    return indexSet
}

public func +(left: NSIndexSet, right: NSIndexSet) -> NSMutableIndexSet {
    let indexSet = left.mutableCopy() as! NSMutableIndexSet
    indexSet.addIndexes(right)
    return indexSet
}
