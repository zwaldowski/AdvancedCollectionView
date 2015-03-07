//
//  DataSource+SectionHeaders.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/31/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

extension DataSource {
    
    /// A header for the data source with a specific title. Uses SectionHeaderView.
    public func addSectionHeader(title: String? = nil) -> SupplementaryMetrics {
        let key = "TitleHeaderKey"
        
        if let cached = self.header(forKey: key) {
            return cached
        }
        
        var header = SupplementaryMetrics(kind: SupplementKind.Header)
        header.measurement = .Estimate(44)
        header.configure { (view: SectionHeaderView, dataSource: DataSource, indexPath) -> () in
            view.leadingLabel.text = title ?? dataSource.title
        }
        
        addHeader(header, forKey: key)
        
        return header
        
    }
    
}