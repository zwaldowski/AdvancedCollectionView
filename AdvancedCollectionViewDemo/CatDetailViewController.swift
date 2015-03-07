//
//  CatDetailViewController.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/4/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

/// Have a cat? Want to know more about it? This view controller will display the details and sightings for a given cat instance.
class CatDetailViewController: CollectionViewController {
    
    var cat: Cat!
    
    private var segmentedDataSource: SegmentedDataSource!
    private lazy var detailDataSource: CatDetailDataSource = {
        let dataSource = CatDetailDataSource(cat: self.cat)
        dataSource.title = NSLocalizedString("Details", comment: "Title of cat details section")
        dataSource.emptyContent = PlaceholderContent(title: NSLocalizedString("No Cat", comment: "The title of the placeholder to show if the cat has no data"), message: NSLocalizedString("This cat has no information.", comment: "The message to show when the cat has no information"))
        dataSource.errorContent = PlaceholderContent(title: NSLocalizedString("Unable to Load", comment: "Error message title to show when unable to load cat details"), message: String.localizedStringWithFormat("A network problem occurred loading details for “%@”.", self.cat.name))
        return dataSource
    }()
    private lazy var sightingsDataSource: CatSightingsDataSource = {
        let dataSource = CatSightingsDataSource(cat: self.cat)
        dataSource.title = NSLocalizedString("Sightings", comment: "Title of cat sightings section");
        dataSource.emptyContent = PlaceholderContent(title: NSLocalizedString("No Sightings", comment: "Title of the no sightings placeholder message"), message: NSLocalizedString("This cat has not been sighted recently.", comment: "The message to show when the cat has not been sighted recently"))
        
        dataSource.defaultMetrics.separatorInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
        dataSource.defaultMetrics.measurement = .Estimate(44)
        return dataSource
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let segmented = SegmentedDataSource()
        
        segmented.add(dataSource: detailDataSource)
        segmented.add(dataSource: sightingsDataSource)
        
        var globalHeader = SupplementaryMetrics(kind: SupplementKind.Header)
        globalHeader.isVisibleWhileShowingPlaceholder = true
        globalHeader.measurement = .Static(110)
        globalHeader.configure {
            [weak self] (view: CatDetailHeader, dataSource, indexPath) in
            if let cat = self?.cat {
                view.configure(cat: cat)
            }
        }
        segmented.addHeader(globalHeader, forKey: "globalHeader")
        
        collectionView?.dataSource = segmented
        segmentedDataSource = segmented
    }
    
}
