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
public typealias Group = dispatch_group_t
public typealias QOS = qos_class_t

public extension Queue {
    
    private class func globalQueue(#qos: QOS) -> Queue {
        return dispatch_get_global_queue(qos, UInt(0))
    }
    
    public class var mainQueue: Queue { return dispatch_get_main_queue() }
    public class var userInteractiveQueue: Queue { return globalQueue(qos: QOS_CLASS_USER_INTERACTIVE) }
    public class var userInitiatedQueue: Queue { return globalQueue(qos: QOS_CLASS_USER_INITIATED) }
    public class var defaultQueue: Queue { return globalQueue(qos: QOS_CLASS_DEFAULT) }
    public class var utilityQueue: Queue { return globalQueue(qos: QOS_CLASS_UTILITY) }
    public class var backgroundQueue: Queue { return globalQueue(qos: QOS_CLASS_BACKGROUND) }
    
}

public struct Async {
    private static var nativeCancellation = {
        floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1
        }()
    
    private final class Wrapper {
        let group = Group()
        var isCancelled = false
        
        func cancellable(block: Block) -> Block {
            return {
                if self.isCancelled { return }
                block()
            }
        }
    }
    
    private enum BlockContainer {
        case Native(Block)
        case Legacy(Wrapper)
    }
    
    private let wrapped: BlockContainer
    
    public func cancel() {
        switch wrapped {
        case .Native(let block):
            dispatch_block_cancel(block)
        case .Legacy(let wrapper):
            wrapper.isCancelled = true
        }
    }
    
    public func chain(queue: Queue, block chainingBlock: Block) -> Async {
        switch wrapped {
        case .Native(let block):
            let child = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, chainingBlock)
            dispatch_block_notify(block, queue, child)
            return Async(wrapped: .Native(child))
        case .Legacy(let wrapper):
            let childWrapper = Async.Wrapper()
            let group = childWrapper.group
            let block = childWrapper.cancellable(chainingBlock)
            dispatch_group_enter(group)
            dispatch_group_notify(wrapper.group, queue) {
                block()
                dispatch_group_leave(group)
            }
            return Async(wrapped: .Legacy(wrapper))
        }
    }
    
}

public func async(queue: Queue, block originalBlock: Block) -> Async {
    if Async.nativeCancellation {
        let block = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, originalBlock)
        dispatch_async(queue, block)
        return Async(wrapped: .Native(block))
    }
    
    let wrapper = Async.Wrapper()
    let block = wrapper.cancellable(originalBlock)
    dispatch_group_async(wrapper.group, queue, block)
    return Async(wrapped: .Legacy(wrapper))
}
