//
//  DataSourceContainer.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/17/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

public enum SectionAction {
    
    case Insert(NSIndexSet, direction: SectionOperationDirection)
    case Remove(NSIndexSet, direction: SectionOperationDirection)
    case Reload(NSIndexSet)
    case Move(from: Int, to: Int, direction: SectionOperationDirection)
    case ReloadGlobal
    
}

public protocol DataSourcePresenter: class {
    
    func dataSourceWillPerform(dataSource: DataSource, sectionAction: SectionAction)
    
}

public enum ItemAction {
    
    case Insert([NSIndexPath])
    case Remove([NSIndexPath])
    case Reload([NSIndexPath])
    case Move(from: NSIndexPath, to: NSIndexPath)
    
    case ReloadAll
    case BatchUpdate(update: () -> (), completion: ((Bool) -> ())?)
    case WillLoad
    case DidLoad(NSError?)
    
}

public protocol DataSourceContainer: DataSourcePresenter {
    
    /// Is this data source "hidden" by a placeholder either of its own or from an enclosing data source. Use this to determine whether to report that there are no items in your data source while loading.
    var isObscuredByPlaceholder: Bool { get }

    func dataSourceWillPerform(dataSource: DataSource, itemAction: ItemAction)
    
}
