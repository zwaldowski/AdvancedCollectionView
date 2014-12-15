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
    case Error(NSError)
    
}
