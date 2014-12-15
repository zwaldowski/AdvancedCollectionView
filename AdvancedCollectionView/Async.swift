//
//  Async.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import Foundation

public typealias Queue = dispatch_queue_t
public typealias Block = dispatch_block_t
public typealias QOS = qos_class_t

private extension Queue {
    
    class func globalQueue(#qos: QOS) -> Queue {
        return dispatch_get_global_queue(qos, UInt(0))
    }
    
    class var mainQueue: Queue { return globalQueue(qos: qos_class_main()) }
    class var userInteractiveQueue: Queue { return globalQueue(qos: QOS_CLASS_USER_INTERACTIVE) }
    class var userInitiatedQueue: Queue { return globalQueue(qos: QOS_CLASS_USER_INITIATED) }
    class var defaultQueue: Queue { return globalQueue(qos: QOS_CLASS_DEFAULT) }
    class var utilityQueue: Queue { return globalQueue(qos: QOS_CLASS_UTILITY) }
    class var backgroundQueue: Queue { return globalQueue(qos: QOS_CLASS_BACKGROUND) }
    
}

public struct Async {
    
    private let block: dispatch_block_t
    
    private init(_ block: dispatch_block_t) {
        self.block = block
    }
    
    public func cancel() {
        dispatch_block_cancel(block)
    }
    
    func chain(queue: Queue, block chainingBlock: () -> ()) -> Async {
        let chainingBlock = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, chainingBlock)
        dispatch_block_notify(self.block, queue, chainingBlock)
        return Async(chainingBlock)
    }
    
}

public func async(queue: Queue, block: () -> ()) -> Async {
    let wrapper = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, block)
    dispatch_async(queue, wrapper)
    return Async(wrapper)
}
