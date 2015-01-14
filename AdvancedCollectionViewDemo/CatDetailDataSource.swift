//
//  CatDetailDataSource.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/4/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

class CatDetailDataSource: ComposedDataSource {
    
    private var cat: Cat
    private let classificationDataSource: KeyValueDataSource<Cat>
    private let descriptionDataSource: TextValueDataSource<Cat>
    
    init(cat: Cat) {
        self.cat = cat
        
        classificationDataSource = KeyValueDataSource(source: cat)
        classificationDataSource.defaultMetrics.measurement = .Static(22)
        classificationDataSource.title = NSLocalizedString("Classification", comment: "Title of the classification data section")
        classificationDataSource.addSectionHeader()
        
        descriptionDataSource = TextValueDataSource(source: cat)
        descriptionDataSource.defaultMetrics.measurement = .Estimate(22)
        
        super.init()
        
        defaultMetrics.separators = nil
        
        add(dataSource: classificationDataSource)
        add(dataSource: descriptionDataSource)
    }
    
    // MARK: DataSource
    
    private func updateChildDataSources() {
        classificationDataSource.source = cat
        classificationDataSource.items = [
            KeyValue(label: NSLocalizedString("Kingdom", comment: "label for kingdom cell"), getValue: { $0.classification?.kingdom }),
            KeyValue(label: NSLocalizedString("Phylum", comment: "label for the phylum cell"), getValue: { $0.classification?.phylum }),
            KeyValue(label: NSLocalizedString("Class", comment: "label for the class cell"), getValue: { $0.classification?.subclass }),
            KeyValue(label: NSLocalizedString("Order", comment: "label for the order cell"), getValue: { $0.classification?.order }),
            KeyValue(label: NSLocalizedString("Family", comment: "label for the family cell"), getValue: { $0.classification?.family }),
            KeyValue(label: NSLocalizedString("Genus", comment: "label for the genus cell"), getValue: { $0.classification?.genus }),
            KeyValue(label: NSLocalizedString("Species", comment: "label for the species cell"), getValue: { $0.classification?.species }),
        ]
        
        descriptionDataSource.source = cat
        descriptionDataSource.items = [
            KeyValue(label: NSLocalizedString("Description", comment: "Title of the description data section"), getValue: { $0.longDescription }),
            KeyValue(label: NSLocalizedString("Habitat", comment: "Title of the habitat data section"), getValue: { $0.habitat }),
        ]
    }
    
    override func loadContent() {
        startLoadingContent { (loading) -> () in
            DataAccessManager.shared.fetchDetail(cat: self.cat) {
                [weak self] (cat) in
                
                switch (self, loading.isCurrent, cat) {
                case (.None, _, _): return
                case (_, false, _): return loading.ignore()
                case (_, _, .None): return loading.error()
                case (.Some(let me), true, .Some(let cat)):
                    me.cat = cat
                    loading.update { me.updateChildDataSources() }
                default: break
                }
            }
        }
    }
    
}
