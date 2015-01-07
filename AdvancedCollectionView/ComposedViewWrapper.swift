//
//  ComposedViewWrapper.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/23/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

// TODO: get rid of proxy!

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

final class ComposedViewWrapper: NSObject {
    
    private let wrapped: UICollectionView
    private var mapping: ComposedMapping

    init(collectionView: UICollectionView, mapping: ComposedMapping) {
        self.wrapped = collectionView
        self.mapping = mapping
    }
    
    // MARK: - Forwarding
    
    override func forwardingTargetForSelector(aSelector: Selector) -> AnyObject? {
        return wrapped
    }
    
    override func respondsToSelector(aSelector: Selector) -> Bool {
        if super.respondsToSelector(aSelector) { return true }
        if let forward: AnyObject = forwardingTargetForSelector(aSelector) {
            return forward.respondsToSelector(aSelector)
        }
        return false
    }
    
    override class func instancesRespondToSelector(aSelector: Selector) -> Bool {
        if aSelector == nil { return false }
        if class_respondsToSelector(self, aSelector) { return true }
        if UICollectionView.respondsToSelector(aSelector) { return true }
        return false
    }

    override func valueForUndefinedKey(key: String) -> AnyObject? {
        return wrapped.valueForKey(key)
    }
    
    override func setValue(value: AnyObject?, forUndefinedKey key: String) {
        wrapped.setValue(value, forUndefinedKey: key)
    }
    
    // MARK: - UICollectionView
    
    func dequeueReusableCellWithReuseIdentifier(identifier: String, forIndexPath indexPath: NSIndexPath!) -> AnyObject {
        return wrapped.dequeueReusableCellWithReuseIdentifier(identifier, forIndexPath: mapping.globalIndexPath(forLocalIndexPath: indexPath))
    }
    
    func dequeueReusableSupplementaryViewOfKind(elementKind: String, withReuseIdentifier identifier: String, forIndexPath indexPath: NSIndexPath!) -> AnyObject {
        return wrapped.dequeueReusableSupplementaryViewOfKind(elementKind, withReuseIdentifier: identifier, forIndexPath: mapping.globalIndexPath(forLocalIndexPath: indexPath))
    }
    
    func indexPathsForSelectedItems() -> [AnyObject] {
        return mapping.localIndexPaths(forGlobalIndexPaths: wrapped.indexPathsForSelectedItems() as [NSIndexPath])
    }
    
    func selectItemAtIndexPath(indexPath: NSIndexPath?, animated: Bool, scrollPosition: UICollectionViewScrollPosition) {
        let globalIndexPath = indexPath.map { self.mapping.globalIndexPath(forLocalIndexPath: $0) }
        wrapped.selectItemAtIndexPath(globalIndexPath, animated: animated, scrollPosition: scrollPosition)
    }
    
    func deselectItemAtIndexPath(indexPath: NSIndexPath?, animated: Bool) {
        let globalIndexPath = indexPath.map { self.mapping.globalIndexPath(forLocalIndexPath: $0) }
        wrapped.deselectItemAtIndexPath(globalIndexPath, animated: animated)
    }
    
    func numberOfItemsInSection(section: Int) -> Int {
        return wrapped.numberOfItemsInSection(mapping.globalSection(forLocalSection: section))
    }
    
    func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        return wrapped.layoutAttributesForItemAtIndexPath(mapping.globalIndexPath(forLocalIndexPath: indexPath))
    }
    
    func layoutAttributesForSupplementaryElementOfKind(kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        return wrapped.layoutAttributesForSupplementaryElementOfKind(kind, atIndexPath: mapping.globalIndexPath(forLocalIndexPath: indexPath))
    }
    
    func indexPathForItemAtPoint(point: CGPoint) -> NSIndexPath? {
        return wrapped.indexPathForItemAtPoint(point).map { self.mapping.localIndexPath(forGlobalIndexPath: $0) }
    }
    
    func indexPathForCell(cell: UICollectionViewCell) -> NSIndexPath? {
        return wrapped.indexPathForCell(cell).map { self.mapping.localIndexPath(forGlobalIndexPath: $0) }
    }
    
    func cellForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewCell? {
        return wrapped.cellForItemAtIndexPath(mapping.globalIndexPath(forLocalIndexPath: indexPath))
    }
    
    func indexPathsForVisibleItems() -> [AnyObject] {
        return mapping.localIndexPaths(forGlobalIndexPaths: wrapped.indexPathsForVisibleItems() as [NSIndexPath])
    }
    
    func scrollToItemAtIndexPath(indexPath: NSIndexPath, atScrollPosition scrollPosition: UICollectionViewScrollPosition, animated: Bool) {
        wrapped.scrollToItemAtIndexPath(mapping.globalIndexPath(forLocalIndexPath: indexPath), atScrollPosition: scrollPosition, animated: animated)
    }
    
    func insertSections(sections: NSIndexSet) {
        wrapped.insertSections(mapping.globalSections(forLocalSections: sections))
    }
    
    func deleteSections(sections: NSIndexSet) {
        wrapped.deleteSections(mapping.globalSections(forLocalSections: sections))
    }
    
    func reloadSections(sections: NSIndexSet) {
        wrapped.reloadSections(mapping.globalSections(forLocalSections: sections))
    }
    
    func moveSection(section: Int, toSection newSection: Int) {
        let globalSection = mapping.globalSection(forLocalSection: section)
        let globalNewSection = mapping.globalSection(forLocalSection: newSection)
        wrapped.moveSection(globalSection, toSection: newSection)
    }
    
    func insertItemsAtIndexPaths(indexPaths: [AnyObject]) {
        wrapped.insertItemsAtIndexPaths(mapping.globalIndexPaths(forLocalIndexPaths: indexPaths as [NSIndexPath]))
    }
    
    func deleteItemsAtIndexPaths(indexPaths: [AnyObject]) {
        wrapped.deleteItemsAtIndexPaths(mapping.globalIndexPaths(forLocalIndexPaths: indexPaths as [NSIndexPath]))
    }
    
    func reloadItemsAtIndexPaths(indexPaths: [AnyObject]) {
        wrapped.reloadItemsAtIndexPaths(mapping.globalIndexPaths(forLocalIndexPaths: indexPaths as [NSIndexPath]))
    }
    
    func moveItemAtIndexPath(indexPath: NSIndexPath, toIndexPath newIndexPath: NSIndexPath) {
        wrapped.moveItemAtIndexPath(mapping.globalIndexPath(forLocalIndexPath: indexPath), toIndexPath: mapping.globalIndexPath(forLocalIndexPath: newIndexPath))
    }
    
}
