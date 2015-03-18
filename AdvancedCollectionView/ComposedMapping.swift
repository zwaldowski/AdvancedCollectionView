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
    
    func localSection(global globalSection: Int) -> Int? {
        return globalToLocal[globalSection]
    }
    
    func globalSection(local localSection: Int) -> Int? {
        return localToGlobal[localSection]
    }
    
    private func toIndexSet<S: SequenceType where S.Generator.Element == Int?>(indexes: S) -> NSIndexSet? {
        return reduce(indexes, NSMutableIndexSet()) { (indexSet: NSMutableIndexSet?, section: Int?) in
            if let indexSet = indexSet, section = section {
                indexSet.addIndex(section)
                return indexSet
            }
            return nil
        }
    }
    
    func localSections(global sections: NSIndexSet) -> NSIndexSet? {
        let mapped = lazy(sections).map { self.localSection(global: $0) }
        return toIndexSet(mapped)
    }
    
    func globalSections<S: SequenceType where S.Generator.Element == Int>(local sections: S) -> NSIndexSet? {
        let mapped = lazy(sections).map { self.globalSection(local: $0) }
        return toIndexSet(mapped)
    }
    
    func localIndexPath(global indexPath: NSIndexPath) -> NSIndexPath? {
        return localSection(global: indexPath.section).map {
            NSIndexPath($0, indexPath.item)
        }
    }
    
    func globalIndexPath(local indexPath: NSIndexPath) -> NSIndexPath? {
        return globalSection(local: indexPath.section).map {
            NSIndexPath($0, indexPath.item)
        }
    }
    
    private func toIndexPaths<S: SequenceType where S.Generator.Element == NSIndexPath?>(indexes: S) -> [NSIndexPath]? {
        return reduce(indexes, []) { (indexPaths: [NSIndexPath]?, indexPath: NSIndexPath?) in
            if let indexPaths = indexPaths, indexPath = indexPath {
                return indexPaths + CollectionOfOne(indexPath)
            }
            return nil
        }
    }
    
    func localIndexPaths(global indexPaths: [NSIndexPath]) -> [NSIndexPath]? {
        let mapped = lazy(indexPaths).map { self.localIndexPath(global: $0) }
        return toIndexPaths(mapped)
    }
    
    func globalIndexPaths(local indexPaths: [NSIndexPath]) -> [NSIndexPath]? {
        let mapped = lazy(indexPaths).map { self.globalIndexPath(local: $0) }
        return toIndexPaths(mapped)
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
