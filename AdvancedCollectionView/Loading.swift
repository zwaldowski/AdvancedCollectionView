//
//  Loading.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import Foundation

public enum LoadingState {

    /// The initial state.
    case Initial
    /// The first load of content.
    case Loading
    /// Subsequent loads after the first.
    case Refreshing
    /// Content has loaded successfully.
    case Loaded
    /// No content is available.
    case NoContent
    /// An error occurred while loading content.
    case Error(NSError?)
    
    var error: NSError? {
        switch self {
        case .Error(let error):
            return error
        default:
            return nil
        }
    }
    
}

public final class Loader {
    
    public typealias Update = () -> ()
    public typealias CompletionHandler = (LoadingState, Update) -> ()

    private var completionHandler: CompletionHandler?
    init(completionHandler: CompletionHandler) {
        self.completionHandler = completionHandler
    }
    
    public var isCurrent = true
    
    private func done(newState: LoadingState? = nil, update: Update = {}) {
        if let block = completionHandler,
            state = newState {
            Async.main {
                block(state, update)
            }
        }
        completionHandler = nil
    }
    
    public func ignore() {
        done()
    }
    
    public func update(content update: Update) {
        done(newState: .Loaded, update: update)
    }
    
    public func error(_ error: NSError? = nil) {
        done(newState: .Error(error))
    }
    
    public func noContent(update: Update) {
        done(newState: .NoContent, update: update)
    }
    
}
