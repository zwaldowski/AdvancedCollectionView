//
//  CatListViewController.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/3/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit
import AdvancedCollectionView

/// The view controller that presents the list of cats. This view controller enables switching between all available cats and the same list in reverse via a segmented control in the navigation bar.
class CatListViewController: CollectionViewController {
    
    override init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init() {
        super.init()
    }
    
    private var segmentedDataSource: SegmentedDataSource!
    private var catsDataSource: CatListDataSource!
    private var reversedCatsDataSource: CatListDataSource!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        catsDataSource = newAllCatsDataSource()
        reversedCatsDataSource = newAllCatsDataSource(reversed: true)
        
        let segmented = SegmentedDataSource()
        
        segmented.defaultMetrics.measurement = .Static(44)
        segmented.defaultMetrics.separatorInsets = UIEdgeInsetsMake(0, 15, 0, 0)
        
        segmented.shouldDisplayDefaultHeader = false
        segmented.add(dataSource: catsDataSource)
        segmented.add(dataSource: reversedCatsDataSource)
        
        segmentedDataSource = segmented
        collectionView?.dataSource = segmented
        
        // Create a segmented control to place in the navigation bar and ask the segmented data source to manage it.
        let segmentedControl = UISegmentedControl(items: [])
        segmented.configureSegmentedControl(segmentedControl)
        navigationItem.titleView = segmentedControl
    }
    
    private func newAllCatsDataSource(reversed: Bool = false) -> CatListDataSource {
        let dataSource = CatListDataSource()
        dataSource.reversed = reversed
        
        if reversed {
            dataSource.title = NSLocalizedString("Reversed", comment: "Title for reversed cats list")
        } else {
            dataSource.title = NSLocalizedString("All", comment: "Title for available cats list")
        }
        
        dataSource.emptyContent = PlaceholderContent(title: NSLocalizedString("No Cats", comment: "The title to show when no cats are available"), message: NSLocalizedString("All the big cats are napping or roaming elsewhere. Please try again later.", comment: "The message to show when no cats are available"))
        dataSource.errorContent = PlaceholderContent(title: NSLocalizedString("Unable To Load Cats", comment: "Title of message to show when unable to load cats"), message: NSLocalizedString("A problem with the network prevented loading the available cats.\nPlease, check your network settings.", comment: "Message to show when unable to load cats"))
        
        return dataSource
    }
    
    private var selectedIndexPath: NSIndexPath?
    
    private var selectedCat: Cat? {
        if let indexPath = selectedIndexPath {
            let dataSource = segmentedDataSource.selectedDataSource as! CatListDataSource
            return dataSource[indexPath]
        }
        return nil
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "detail" {
            let destination = segue.destinationViewController as! CatDetailViewController
            destination.cat = selectedCat
        }
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        selectedIndexPath = indexPath
        performSegueWithIdentifier("detail", sender: self)
    }
    
}
