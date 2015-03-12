//
//  OrderedDictionaryTests.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/8/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import XCTest
import AdvancedCollectionView

class OrderedDictionaryTests: XCTestCase {
    
    typealias TestOrderedDictionary = OrderedDictionary<String, Int>
    var d: TestOrderedDictionary!

    override func setUp() {
        super.setUp()
        
        d = OrderedDictionary()
        d["0"] = 1
        d["1"] = 2
        d["3"] = 4
        d["2"] = 3
        d["1"] = 7
        d.removeValueForKey("3")
        
        XCTAssertFalse(d.isEmpty)
        XCTAssertEqual(d.count, 3)
    }
    
    override func tearDown() {
        d = nil

        super.tearDown()
    }
    
    func testEquivalentDictionary() {
        var d2 = [String: Int]()
        d2["0"] = 1
        d2["1"] = 2
        d2["3"] = 4
        d2["2"] = 3
        d2["1"] = 7
        d2.removeValueForKey("3")
        
        XCTAssertFalse(equal(d2.keys, ["0", "1", "2"]))
        XCTAssert(d2["0"] == 1)
        XCTAssert(d2["1"] == 7)
        XCTAssert(d2["2"] == 3)
    }
    
    func testOrderPreserved() {
        XCTAssertTrue(equal(d.keys, ["0", "1", "2"]))
        XCTAssert(d["0"] == 1)
        XCTAssert(d["1"] == 7)
        XCTAssert(d["2"] == 3)
    }
    
    func testInitSequence() {
        let seq: [TestOrderedDictionary.Element] = [("3", 900), ("2", 1000), ("1", 2000)]
        let dict = OrderedDictionary(seq)
        XCTAssertTrue(equal(dict.keys, ["3", "2", "1"]))
    }
    
    func testIndexing() {
        XCTAssertEqual(d.startIndex, 0)
        XCTAssertEqual(d.endIndex, d.count)
        
        XCTAssert(d["0"] == 1)
        
        let el = d[0]
        XCTAssertEqual(el.0, "0")
        XCTAssertEqual(el.1, 1)
        
        let slice: ArraySlice<String> = [ "0", "1" ]
        XCTAssertEqual(d[0...1], slice)
    }
    
    func testReplaceRange() {
        d.replaceRange(0...1, with: [("7", 64)])
        XCTAssertTrue(equal(d.keys, ["7", "2"]))
    }
    
    func testRemoveAtIndex() {
        let el = d.removeAtIndex(0)
        XCTAssertEqual(el.0, "0")
        XCTAssertEqual(el.1, 1)
        
        XCTAssertTrue(equal(d.keys, ["1", "2"]))
    }
    
    func testRemoveAll() {
        d.removeAll()
        XCTAssert(d.isEmpty)
        XCTAssertEqual(d.count, 0)
    }
    
    func testSort() {
        d.sortKeys(keyIsOrderedBefore: >)
        XCTAssertTrue(equal(d.keys, ["2", "1", "0"]))
    }
    
    

}
