//
//  OrderedSetTests.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/10/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import XCTest
import AdvancedCollectionView

class OrderedSetTests: XCTestCase {
    
    typealias TestSet = OrderedSet<Int>
    
    func testEmptySet() {
        let set = TestSet()
        XCTAssert(set.isEmpty)
        XCTAssertEqual(set.count, 0)
        
        let set2 = TestSet(minimumCapacity: 3)
        XCTAssert(set2.isEmpty)
        XCTAssertEqual(set2.count, 0)
    }
    
    func testBaseAssumptions() {
        var set = TestSet(1, 2, 3)
        
        XCTAssertFalse(set.contains(4))
        set.insert(4)
        XCTAssert(set.contains(4))
        
        XCTAssert(set.contains(3))
        XCTAssertNotNil(set.remove(3))
        XCTAssertFalse(set.contains(3))
    }
    
    func testSubset() {
        XCTAssert(TestSet(1).isSubsetOf(TestSet(1, 2, 3)))
        XCTAssert(TestSet(1).isSubsetOf(TestSet(1, 2)))
    }
    
    func testSubsetIncludesSelf() {
        XCTAssert(TestSet(1).isSubsetOf(TestSet(1)))
        XCTAssert(TestSet(1, 2, 3).isSubsetOf(TestSet(1, 2, 3)))
    }
    
    func testStrictSupersetIsNotSubset() {
        XCTAssertFalse(TestSet(1, 2, 3, 4).isSubsetOf(TestSet(1, 2, 3)))
    }
    
    func testEmptySetIsAlwaysSubset() {
        XCTAssert(TestSet().isSubsetOf(TestSet()))
        XCTAssert(TestSet().isSubsetOf(TestSet(1, 2, 3)))
    }
    
    func testSuperset() {
        XCTAssert(TestSet(1, 2, 3).isSupersetOf(TestSet(1)))
        XCTAssert(TestSet(1, 2).isSupersetOf(TestSet(1)))
    }
    
    func testSupersetIncludesSelf() {
        XCTAssert(TestSet(1).isSupersetOf(TestSet(1)))
        XCTAssert(TestSet(1, 2, 3).isSupersetOf(TestSet(1, 2, 3)))
    }
    
    func testStrictSubsetIsNotSuperset() {
        XCTAssertFalse(TestSet(1, 2, 3).isSupersetOf(TestSet(1, 2, 3, 4)))
    }
    
    func testAlwaysSupersetOfEmptySet() {
        XCTAssert(TestSet().isSupersetOf(TestSet()))
        XCTAssert(TestSet(1, 2, 3).isSupersetOf(TestSet()))
    }
    
    func testUnion() {
        XCTAssert(TestSet(1, 2, 3, 4).union([3, 4, 5]) == TestSet(1, 2, 3, 4, 5))
        
        var c = TestSet(1, 2, 3)
        c.unionInPlace([3, 4, 5])
        XCTAssert(c == TestSet(1, 2, 3, 4, 5))
    }
    
    func testIntersection() {
        XCTAssert(TestSet(1, 2, 3).intersect([2, 3, 4]) == TestSet(2, 3))
        
        var set = TestSet(1, 2, 3)
        set.intersectInPlace([2, 3, 4])
        XCTAssert(set == TestSet(2, 3))
    }
    
    func testDifference() {
        XCTAssert(TestSet(1, 2, 3).subtract([2, 3, 4]) == TestSet(1))
        
        var set = TestSet(1, 2, 3)
        set.subtractInPlace([2, 3, 4])
        XCTAssert(set == TestSet(1))
    }
    
    func testOrderFundamentals() {
        var set = TestSet()
        set.append(3)
        set.append(2)
        set.append(1)
        set.append(2)
        
        XCTAssert(set == TestSet(3, 2, 1))
        XCTAssert(equal(set, [3, 2, 1]))
    }
    
    func testFilter() {
        XCTAssert(TestSet(1, 2, 3).filter { $0 == 2 } == TestSet(2))
    }
    
    func testReduce() {
        XCTAssert(TestSet(1, 2, 3).reduce(0, combine: +) == 6)
    }
    
    func testMap() {
        XCTAssert(TestSet(1, 2, 3).map(toString) == OrderedSet("1", "2", "3"))
    }

}
