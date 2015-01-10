//
//  SetTests.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/10/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import XCTest
import AdvancedCollectionView

class SetTests: XCTestCase {
    
    func testEmptySet() {
        let set = Set<Int>()
        XCTAssert(set.isEmpty)
        XCTAssertEqual(set.count, 0)
        
        let set2 = Set<Int>(minimumCapacity: 3)
        XCTAssert(set2.isEmpty)
        XCTAssertEqual(set2.count, 0)
    }
    
    func testBaseAssumptions() {
        var set = Set(1, 2, 3)
        
        XCTAssertFalse(set.contains(4))
        set.insert(4)
        XCTAssert(set.contains(4))
        
        XCTAssert(set.contains(3))
        XCTAssert(set.remove(3))
        XCTAssertFalse(set.contains(3))
    }
    
    func testSubset() {
        XCTAssert(subset(Set(1), Set(1, 2, 3)))
        XCTAssert(subset(Set(1), Set(1, 2)))
    }
    
    func testSubsetIncludesSelf() {
        XCTAssert(subset(Set(1), Set(1)))
        XCTAssert(subset(Set(1, 2, 3), Set(1, 2, 3)))
    }

    func testStrictSupersetIsNotSubset() {
        XCTAssertFalse(subset(Set(1, 2, 3, 4), Set(1, 2, 3)))
    }

    func testEmptySetIsAlwaysSubset() {
        XCTAssert(subset(Set(), Set<Int>()))
        XCTAssert(subset(Set(), Set(1, 2, 3)))
    }

    func testSuperset() {
        XCTAssert(superset(Set(1, 2, 3), Set(1)))
        XCTAssert(superset(Set(1, 2), Set(1)))
    }

    func testSupersetIncludesSelf() {
        XCTAssert(superset(Set(1), Set(1)))
        XCTAssert(superset(Set(1, 2, 3), Set(1, 2, 3)))
    }

    func testStrictSubsetIsNotSuperset() {
        XCTAssertFalse(superset(Set(1, 2, 3), Set(1, 2, 3, 4)))
    }
    
    func testAlwaysSupersetOfEmptySet() {
        XCTAssert(superset(Set<Int>(), Set()))
        XCTAssert(superset(Set(1, 2, 3), Set()))
    }
    
    func testFilter() {
        XCTAssert(Set(1, 2, 3).filter { $0 == 2 } == Set(2))
    }
    
    func testReduce() {
        XCTAssert(Set(1, 2, 3).reduce(0, +) == 6)
    }
    
    func testMap() {
        XCTAssert(Set(1, 2, 3).map(toString) == Set("1", "2", "3"))
    }
    
    func testFlatMap() {
        XCTAssert(Set(1, 2).flatMap { [$0, $0 * 2] } == Set(1, 2, 4))
    }
    
    func testUnion() {
        XCTAssert(Set(1, 2, 3, 4) + Set(3, 4, 5) == Set(1, 2, 3, 4, 5))
        
        var c: Set<Int> = [1, 2, 3]
        c += Set(3, 4, 5)
        XCTAssert(c == Set(1, 2, 3, 4, 5))
    }
    
    func testIntersection() {
        XCTAssert(Set(1, 2, 3) & Set(2, 3, 4) == Set(2, 3))
        
        var set = Set(1, 2, 3)
        set &= Set(2, 3, 4)
        XCTAssert(set == Set(2, 3))
    }
    
    func testDifference() {
        XCTAssert(Set(1, 2, 3) - Set(2, 3, 4) == Set(1))
        
        var set = Set(1, 2, 3)
        set -= Set(2, 3, 4)
        XCTAssert(set == Set(1))
    }

}
