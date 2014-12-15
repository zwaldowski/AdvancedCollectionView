//
//  Foundation.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import Foundation

func assertMainThread(file: StaticString = __FILE__, line: UWord = __LINE__) {
    assert(NSThread.isMainThread(), "This code must be called on the main thread.")
}

public extension NSIndexSet {
    
    convenience init(range: Range<Int>) {
        self.init(indexesInRange: NSMakeRange(range.startIndex, range.endIndex - range.startIndex))
    }
    
}

public func ==(lhs: NSIndexPath, rhs: NSIndexPath) -> Bool {
    return lhs.compare(rhs) == .OrderedSame
}
public func <(lhs: NSIndexPath, rhs: NSIndexPath) -> Bool {
    return lhs.compare(rhs) == .OrderedAscending
    
}

extension NSIndexPath: Comparable { }

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
