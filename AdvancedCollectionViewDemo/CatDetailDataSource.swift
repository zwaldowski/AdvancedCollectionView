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
    
    private let cat: AAPLCat
    private let classificationDataSource: KeyValueDataSource<AAPLCat>
    private let descriptionDataSource: TextValueDataSource<AAPLCat>
    
    init(cat: AAPLCat) {
        self.cat = cat
        
        classificationDataSource = KeyValueDataSource(source: cat)
        classificationDataSource.defaultMetrics.measurement = .Static(22)
        classificationDataSource.title = NSLocalizedString("Classification", comment: "Title of the classification data section")
        classificationDataSource.addSectionHeader()
        
        descriptionDataSource = TextValueDataSource(source: cat)
        descriptionDataSource.defaultMetrics.measurement = .Estimate(22)
        
        super.init()
        
        add(dataSource: classificationDataSource)
        add(dataSource: descriptionDataSource)
    }
    
    // MARK: DataSource
    
    private func updateChildDataSources() {
        classificationDataSource.items = [
            KeyValue(label: NSLocalizedString("Kingdom", comment: "label for kingdom cell"), getValue: { $0.classificationKingdom }),
            KeyValue(label: NSLocalizedString("Phylum", comment: "label for the phylum cell"), getValue: { $0.classificationPhylum }),
            KeyValue(label: NSLocalizedString("Class", comment: "label for the class cell"), getValue: { $0.classificationClass }),
            KeyValue(label: NSLocalizedString("Order", comment: "label for the order cell"), getValue: { $0.classificationOrder }),
            KeyValue(label: NSLocalizedString("Family", comment: "label for the family cell"), getValue: { $0.classificationFamily }),
            KeyValue(label: NSLocalizedString("Genus", comment: "label for the genus cell"), getValue: { $0.classificationGenus }),
            KeyValue(label: NSLocalizedString("Species", comment: "label for the species cell"), getValue: { $0.classificationSpecies }),
        ]
        
        descriptionDataSource.items = [
            KeyValue(label: NSLocalizedString("Description", comment: "Title of the description data section"), getValue: { $0.longDescription }),
            KeyValue(label: NSLocalizedString("Habitat", comment: "Title of the habitat data section"), getValue: { $0.habitat }),
        ]
    }
    
    override func loadContent() {
        startLoadingContent { (loading) -> () in
            AAPLDataAccessManager.shared().fetchDetailForCat(self.cat) {
                [weak self]
                (cat, error) in
                
                if self == nil { return }
                
                if !loading.isCurrent {
                    loading.ignore()
                    return
                }
                
                if error != nil {
                    loading.error(error)
                    return
                }
                
                loading.update { self!.updateChildDataSources() }
            }
            
        }
    }
    
}
