//
//  MultimapTests.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/10/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import XCTest
import AdvancedCollectionView

func ==<T1: Equatable, T2: Equatable>(lhs: (T1, T2), rhs: (T1, T2)) -> Bool {
    return lhs.0 == rhs.0 && lhs.1 == rhs.1
}

class MultimapTests: XCTestCase {
    
    typealias TestMultimap = Multimap<Int, Int>
    var d: TestMultimap!
    
    override func setUp() {
        super.setUp()
        
        d = [ 1: [3, 5, 7] ]
        
        XCTAssertFalse(d.isEmpty)
        XCTAssertEqual(d.count, 3)
    }
    
    override func tearDown() {
        d = nil
        
        super.tearDown()
    }

    func testOrder() {
        var generator = d.generate()
        XCTAssert(generator.next()! == (1, 3))
        XCTAssert(generator.next()! == (1, 5))
        XCTAssert(generator.next()! == (1, 7))
    }
    
    func testRemove() {
        XCTAssertNotNil(d.remove(valuesForKey: 1))
        XCTAssertFalse(d.contains(1))
        XCTAssertTrue(d.isEmpty)
        XCTAssertEqual(d.count, 0)
    }
    
    func testRemoveValue() {
        d.remove(fromKey: 1, atIndex: 2)
        XCTAssertEqual(d[1].count, 2)
        XCTAssertNil(find(d[1], 7))
        
        d.remove(fromKey: 1, atIndex: 1)
        XCTAssertEqual(d[1].count, 1)
        XCTAssertNil(find(d[1], 5))
        
        d.remove(fromKey: 1, atIndex: 0)
        XCTAssertFalse(d.contains(1))
    }

}