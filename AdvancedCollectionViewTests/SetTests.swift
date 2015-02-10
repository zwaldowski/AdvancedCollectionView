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
    
    typealias TestSet = Set<Int>
    
    func testEmptySet() {
        let set = TestSet()
        XCTAssert(set.isEmpty)
        XCTAssertEqual(set.count, 0)
        
        let set2 = TestSet(minimumCapacity: 3)
        XCTAssert(set2.isEmpty)
        XCTAssertEqual(set2.count, 0)
    }
    
    func testBaseAssumptions() {
        var set = TestSet(arrayLiteral: 1, 2, 3)
        
        XCTAssertFalse(set.contains(4))
        set.insert(4)
        XCTAssert(set.contains(4))
        
        XCTAssert(set.contains(3))
        XCTAssert(set.remove(3))
        XCTAssertFalse(set.contains(3))
    }
    
    func testSubset() {
        XCTAssert(subset(TestSet(1), TestSet(1, 2, 3)))
        XCTAssert(subset(TestSet(1), TestSet(1, 2)))
    }
    
    func testSubsetIncludesSelf() {
        XCTAssert(subset(TestSet(1), TestSet(1)))
        XCTAssert(subset(TestSet(1, 2, 3), TestSet(1, 2, 3)))
    }

    func testStrictSupersetIsNotSubset() {
        XCTAssertFalse(subset(TestSet(1, 2, 3, 4), TestSet(1, 2, 3)))
    }

    func testEmptySetIsAlwaysSubset() {
        XCTAssert(subset(TestSet(), TestSet()))
        XCTAssert(subset(TestSet(), TestSet(1, 2, 3)))
    }

    func testSuperset() {
        XCTAssert(superset(TestSet(1, 2, 3), TestSet(1)))
        XCTAssert(superset(TestSet(1, 2), TestSet(1)))
    }

    func testSupersetIncludesSelf() {
        XCTAssert(superset(TestSet(1), TestSet(1)))
        XCTAssert(superset(TestSet(1, 2, 3), TestSet(1, 2, 3)))
    }

    func testStrictSubsetIsNotSuperset() {
        XCTAssertFalse(superset(TestSet(1, 2, 3), TestSet(1, 2, 3, 4)))
    }
    
    func testAlwaysSupersetOfEmptySet() {
        XCTAssert(superset(TestSet(), TestSet()))
        XCTAssert(superset(TestSet(1, 2, 3), TestSet()))
    }
    
    func testUnion() {
        XCTAssert(TestSet(1, 2, 3, 4) + TestSet(3, 4, 5) == TestSet(1, 2, 3, 4, 5))
        
        var c = TestSet(arrayLiteral: 1, 2, 3)
        c += TestSet(3, 4, 5)
        XCTAssert(c == TestSet(1, 2, 3, 4, 5))
    }
    
    func testIntersection() {
        XCTAssert(TestSet(1, 2, 3) & Set(2, 3, 4) == TestSet(2, 3))
        
        var set = TestSet(arrayLiteral: 1, 2, 3)
        set &= TestSet(2, 3, 4)
        XCTAssert(set == TestSet(2, 3))
    }
    
    func testDifference() {
        XCTAssert(TestSet(1, 2, 3) - TestSet(2, 3, 4) == TestSet(1))
        
        var set = TestSet(arrayLiteral: 1, 2, 3)
        set -= TestSet(2, 3, 4)
        XCTAssert(set == TestSet(1))
    }
    
    func testFilter() {
        XCTAssert(TestSet(1, 2, 3).filter { $0 == 2 } == TestSet(2))
    }
    
    func testReduce() {
        XCTAssert(TestSet(1, 2, 3).reduce(0, +) == 6)
    }
    
    func testMap() {
        XCTAssert(TestSet(1, 2, 3).map(toString) == Set("1", "2", "3"))
    }
    
    func testFlatMap() {
        XCTAssert(TestSet(1, 2).flatMap { [$0, $0 * 2] } == TestSet(1, 2, 4))
    }

}
