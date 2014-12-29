//
//  DataSourceContainer.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/17/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

private func string(fromIndexSet indexSet: NSIndexSet) -> String {
    return join(", ", lazy(indexSet).map(toString))
}

private func string(fromIndexPath indexPath: NSIndexPath) -> String {
    let str = join(", ", lazy(indexPath).map(toString))
    return "{\(str)}"
}

private func string(fromIndexPaths indexPaths: [NSIndexPath]) -> String {
    return join(", ", lazy(indexPaths).map {
        return string(fromIndexPath: $0)
    })
}

public enum SectionAction {
    
    case Insert(NSIndexSet, direction: SectionOperationDirection)
    case Remove(NSIndexSet, direction: SectionOperationDirection)
    case Reload(NSIndexSet)
    case Move(from: Int, to: Int, direction: SectionOperationDirection)
    case ReloadGlobal
    
}

extension SectionAction: DebugPrintable {
    
    public var debugDescription: String {
        switch self {
        case .Insert(let indexSet, _):
            return "INSERT SECTIONS: \(string(fromIndexSet: indexSet))"
        case .Remove(let indexSet, _):
            return "DELETE SECTIONS: \(string(fromIndexSet: indexSet))"
        case .Reload(let indexSet):
            return "REFRESH SECTIONS: \(string(fromIndexSet: indexSet))"
        case .Move(let from, let to, _):
            return "MOVE SECTION: \(from) TO: \(to)"
        case .ReloadGlobal:
            return "RELOAD GLOBAL SECTION"
        }
    }
    
}

public protocol DataSourcePresenter: NSObjectProtocol {
    
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

extension ItemAction: DebugPrintable {
    
    public var debugDescription: String {
        switch self {
        case .Insert(let indexPaths):
            return "INSERT ITEMS: \(string(fromIndexPaths: indexPaths))"
        case .Remove(let indexPaths):
            return "REMOVE ITEMS: \(string(fromIndexPaths: indexPaths))"
        case .Reload(let indexPaths):
            return "REFRESH ITEMS: \(string(fromIndexPaths: indexPaths))"
        case .Move(let from, let to):
            return "MOVE ITEM: \(string(fromIndexPath: from)) TO: \(string(fromIndexPath: to))"
        case .ReloadAll:
            return "RELOAD"
        case .BatchUpdate(_, let completion):
            return "BATCH UPDATE (completion: \(completion != nil))"
        case .WillLoad:
            return "WILL LOAD"
        case .DidLoad(let error):
            if let error = error {
                return "LOADED WITH ERROR: \(error)"
            }
            return "LOADED"
        }
    }
    
}

public protocol DataSourceContainer: DataSourcePresenter {
    
    /// Is this data source "hidden" by a placeholder either of its own or from an enclosing data source. Use this to determine whether to report that there are no items in your data source while loading.
    var isObscuredByPlaceholder: Bool { get }

    func dataSourceWillPerform(dataSource: DataSource, itemAction: ItemAction)
    
}
