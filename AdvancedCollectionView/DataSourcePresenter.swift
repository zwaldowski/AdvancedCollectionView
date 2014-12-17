//
//  DataSourcePresenter.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/17/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

public protocol DataSourcePresenter: class {
    
    /// Is this data source "hidden" by a placeholder either of its own or from an enclosing data source. Use this to determine whether to report that there are no items in your data source while loading.
    var isObscuredByPlaceholder: Bool { get }
    
    func dataSourceDidInsertItems(dataSource: DataSource, indexPaths: [NSIndexPath])
    func dataSourceDidRemoveItems(dataSource: DataSource, indexPaths: [NSIndexPath])
    func dataSourceDidReloadItems(dataSource: DataSource, indexPaths: [NSIndexPath])
    func dataSourceDidMoveItem(dataSource: DataSource, from: NSIndexPath, to: NSIndexPath)
    
    func dataSourceDidInsertSections(dataSource: DataSource, indexes: NSIndexSet, direction: SectionOperationDirection)
    func dataSourceDidRemoveSections(dataSource: DataSource, indexes: NSIndexSet, direction: SectionOperationDirection)
    func dataSourceDidReloadSections(dataSource: DataSource, indexes: NSIndexSet)
    func dataSourceDidMoveSection(dataSource: DataSource, from: Int, to: Int, direction: SectionOperationDirection)
    
    func dataSourceDidReloadData(dataSource: DataSource)
    func dataSourceDidReloadGlobalSection(dataSource: DataSource)
    func dataSourcePerformBatchUpdate(dataSource: DataSource, update: () -> (), completion: ((Bool) -> ())?)
    
    func dataSourceWillLoadContent(dataSource: DataSource)
    func dataSourceDidLoadContent(dataSource: DataSource, error: NSError?)
    
}
