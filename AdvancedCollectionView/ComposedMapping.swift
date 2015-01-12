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
    
    func localSection(forGlobalSection globalSection: Int) -> Int {
        return globalToLocal[globalSection]!
    }
    
    func globalSection(forLocalSection localSection: Int) -> Int {
        return localToGlobal[localSection]!
    }
    
    func localSections(forGlobalSections sections: NSIndexSet) -> NSIndexSet {
        return sections.map { self.localSection(forGlobalSection: $0) }
    }
    
    func globalSections<S: SequenceType where S.Generator.Element == Int>(forLocalSections sequence: S) -> NSIndexSet {
        return NSIndexSet(indexes: lazy(sequence).map({ self.globalSection(forLocalSection: $0) }))
    }
    
    func globalSections(forNumberOfSections sections: Int) -> NSIndexSet {
        return globalSections(forLocalSections: 0..<sections)
    }
    
    func localIndexPath(forGlobalIndexPath indexPath: NSIndexPath) -> NSIndexPath {
        let section = localSection(forGlobalSection: indexPath.section)
        return NSIndexPath(section, indexPath.item)
    }
    
    func globalIndexPath(forLocalIndexPath indexPath: NSIndexPath) -> NSIndexPath {
        let section = globalSection(forLocalSection: indexPath.section)
        return NSIndexPath(section, indexPath.item)
    }
    
    func localIndexPaths(forGlobalIndexPaths indexPaths: [NSIndexPath]) -> [NSIndexPath] {
        return indexPaths.map { self.localIndexPath(forGlobalIndexPath: $0) }
    }
    
    func globalIndexPaths(forLocalIndexPaths indexPaths: [NSIndexPath]) -> [NSIndexPath] {
        return indexPaths.map { self.globalIndexPath(forLocalIndexPath: $0) }
    }
    
    mutating func addMapping(fromGlobalSection globalSection: Int, toLocalSection localSection: Int) {
        assert(localToGlobal.indexForKey(localSection) == nil, "collision while trying to add to a mapping")
        
        globalToLocal[globalSection] = localSection
        localToGlobal[localSection] = globalSection
    }
    
    mutating func updateMappings(startingWithGlobalSection globalSection: Int, dataSource: DataSource) -> Int {
        globalToLocal.removeAll(keepCapacity: true)
        localToGlobal.removeAll(keepCapacity: true)
        
        var endGlobalSection = globalSection
        
        for localSection in 0..<dataSource.numberOfSections {
            addMapping(fromGlobalSection: endGlobalSection++, toLocalSection: localSection)
        }
        
        return endGlobalSection
    }
    
}
