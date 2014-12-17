//
//  Types.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/15/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import Foundation

public enum SectionOperationDirection {
    case None, Left, Right
}

// MARK: Bitmasks

@transparent func contains<T where T: RawOptionSetType, T: NilLiteralConvertible>(mask: T, bit: T) -> Bool {
    return (mask & bit) != nil
}
