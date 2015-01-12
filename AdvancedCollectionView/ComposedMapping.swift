//
//  ComposedMapping.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/23/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

struct ComposedMapping {
    
    private var globalToLocal = [Int: Int]()
    private var localToGlobal = [Int: Int]()
    
    init() {}
    
}

extension ComposedMapping {
    
    func localSection(global globalSection: Int) -> Int {
        return globalToLocal[globalSection]!
    }
    
    func globalSection(local localSection: Int) -> Int {
        return localToGlobal[localSection]!
    }
    
    func localSections(global sections: NSIndexSet) -> NSIndexSet {
        return sections.map { self.localSection(global: $0) }
    }
    
    func globalSections<S: SequenceType where S.Generator.Element == Int>(local sequence: S) -> NSIndexSet {
        return NSIndexSet(indexes: lazy(sequence).map({ self.globalSection(local: $0) }))
    }
    
    func localIndexPath(global indexPath: NSIndexPath) -> NSIndexPath {
        let section = localSection(global: indexPath.section)
        return NSIndexPath(section, indexPath.item)
    }
    
    func globalIndexPath(local indexPath: NSIndexPath) -> NSIndexPath {
        let section = globalSection(local: indexPath.section)
        return NSIndexPath(section, indexPath.item)
    }
    
    func localIndexPaths(global indexPaths: [NSIndexPath]) -> [NSIndexPath] {
        return indexPaths.map { self.localIndexPath(global: $0) }
    }
    
    func globalIndexPaths(local indexPaths: [NSIndexPath]) -> [NSIndexPath] {
        return indexPaths.map { self.globalIndexPath(local: $0) }
    }
    
    mutating func addMapping(fromGlobalSection globalSection: Int, toLocalSection localSection: Int) {
        assert(localToGlobal.indexForKey(localSection) == nil, "collision while trying to add to a mapping")
        
        globalToLocal[globalSection] = localSection
        localToGlobal[localSection] = globalSection
    }
    
    mutating func updateMappings(startingGlobalSection globalSection: Int, dataSource: DataSource) -> Int {
        globalToLocal.removeAll(keepCapacity: true)
        localToGlobal.removeAll(keepCapacity: true)
        
        var endGlobalSection = globalSection
        
        for localSection in 0..<dataSource.numberOfSections {
            addMapping(fromGlobalSection: endGlobalSection++, toLocalSection: localSection)
        }
        
        return endGlobalSection
    }
    
}
