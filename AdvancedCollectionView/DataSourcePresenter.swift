//
//  DataSourceContainer.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/17/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

public protocol DataSourcePresenter: class {
    
    func dataSourceWillInsertSections(dataSource: DataSource, indexes: NSIndexSet, direction: SectionOperationDirection)
    func dataSourceWillRemoveSections(dataSource: DataSource, indexes: NSIndexSet, direction: SectionOperationDirection)
    func dataSourceWillMoveSection(dataSource: DataSource, from: Int, to: Int, direction: SectionOperationDirection)
    
    func dataSourceDidReloadGlobalSection(dataSource: DataSource)

}

public protocol DataSourceContainer: DataSourcePresenter {
    
    /// Is this data source "hidden" by a placeholder either of its own or from an enclosing data source. Use this to determine whether to report that there are no items in your data source while loading.
    var isObscuredByPlaceholder: Bool { get }
    
    func dataSourceDidInsertItems(dataSource: DataSource, indexPaths: [NSIndexPath])
    func dataSourceDidRemoveItems(dataSource: DataSource, indexPaths: [NSIndexPath])
    func dataSourceDidReloadItems(dataSource: DataSource, indexPaths: [NSIndexPath])
    func dataSourceDidMoveItem(dataSource: DataSource, from: NSIndexPath, to: NSIndexPath)
    
    func dataSourceDidReloadSections(dataSource: DataSource, indexes: NSIndexSet)
    
    func dataSourceDidReloadData(dataSource: DataSource)
    func dataSourcePerformBatchUpdate(dataSource: DataSource, update: () -> (), completion: ((Bool) -> ())?)
    
    func dataSourceWillLoadContent(dataSource: DataSource)
    func dataSourceDidLoadContent(dataSource: DataSource, error: NSError?)
    
}
