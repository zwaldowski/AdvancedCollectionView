//
//  CatSighting.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/8/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import Foundation

struct CatSighting {
    let date: NSDate
    let catFancier: String
    let shortDescription: String
}

func ==(lhs: CatSighting, rhs: CatSighting) -> Bool {
    return lhs.date.isEqualToDate(rhs.date) && lhs.catFancier == rhs.catFancier
}

extension CatSighting: Hashable {
    
    var hashValue: Int {
        let prime = 31
        var result = 1
        result = prime &* result &+ date.hashValue
        result = prime &* result &+ catFancier.hashValue
        return result
    }
    
}
