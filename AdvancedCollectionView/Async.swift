//
//  Async.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import Foundation

public typealias Block = @objc_block () -> ()

public struct Async {
    
    private final class Wrapper {
        let group = dispatch_group_create()
        var isCancelled = false
        
        func cancellable(block: Block) -> Block {
            return {
                if self.isCancelled { return }
                block()
            }
        }
    }
    
    private enum BlockStorage {
        case Native(Block)
        case Legacy(Wrapper)
    }
    
    private let storage: BlockStorage
    private init(storage: BlockStorage) {
        self.storage = storage
    }
    
}

// MARK: Continuation

extension Async {

    public func cancel() {
        switch storage {
        case .Native(let block):
            dispatch_block_cancel(block)
        case .Legacy(let wrapper):
            wrapper.isCancelled = true
        }
    }
    
    public func chain(onQueue queue: dispatch_queue_t, block chainingBlock: Block) -> Async {
        switch storage {
        case .Native(let block):
            let child = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, chainingBlock)
            dispatch_block_notify(block, queue, child)
            return Async(storage: .Native(child))
        case .Legacy(let wrapper):
            let childWrapper = Async.Wrapper()
            let group = childWrapper.group
            let block = childWrapper.cancellable(chainingBlock)
            dispatch_group_enter(group)
            dispatch_group_notify(wrapper.group, queue) {
                block()
                dispatch_group_leave(group)
            }
            return Async(storage: .Legacy(wrapper))
        }
    }
    
}

// MARK: Dispatching

extension Async {
    
    public static func send(onQueue queue: dispatch_queue_t)(originalBlock: Block) -> Async {
        if Constants.isiOS7 {
            let wrapper = Async.Wrapper()
            let block = wrapper.cancellable(originalBlock)
            dispatch_group_async(wrapper.group, queue, block)
            return Async(storage: .Legacy(wrapper))
        }
        
        let block = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, originalBlock)
        dispatch_async(queue, block)
        return Async(storage: .Native(block))
    }
    
    public typealias DispatchOnto = Block -> Async
    
    public static var main: DispatchOnto {
        return send(onQueue: dispatch_get_main_queue())
    }
    
    private static func globalQueue(#qos: qos_class_t) -> DispatchOnto {
        return send(onQueue: dispatch_get_global_queue(qos, UInt(0)))
    }
    
    public static var userInteractiveQueue: DispatchOnto { return globalQueue(qos: QOS_CLASS_USER_INTERACTIVE) }
    public static var userInitiatedQueue: DispatchOnto { return globalQueue(qos: QOS_CLASS_USER_INITIATED) }
    public static var defaultQueue: DispatchOnto { return globalQueue(qos: QOS_CLASS_DEFAULT) }
    public static var utilityQueue: DispatchOnto { return globalQueue(qos: QOS_CLASS_UTILITY) }
    public static var backgroundQueue: DispatchOnto { return globalQueue(qos: QOS_CLASS_BACKGROUND) }
    
}
