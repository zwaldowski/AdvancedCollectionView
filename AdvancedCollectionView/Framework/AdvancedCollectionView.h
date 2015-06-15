//
//  AdvancedCollectionView.h
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 6/14/15.
//  Copyright © 2015 Apple. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for AdvancedCollectionView.
FOUNDATION_EXPORT double AdvancedCollectionViewVersionNumber;

//! Project version string for AdvancedCollectionView.
FOUNDATION_EXPORT const unsigned char AdvancedCollectionViewVersionString[];

// Data Sources
#import <AdvancedCollectionView/AAPLBasicDataSource.h>
#import <AdvancedCollectionView/AAPLComposedDataSource.h>
#import <AdvancedCollectionView/AAPLDataSource.h>
#import <AdvancedCollectionView/AAPLDataSourceMetrics.h>
#import <AdvancedCollectionView/AAPLKeyValueDataSource.h>
#import <AdvancedCollectionView/AAPLSegmentedDataSource.h>
#import <AdvancedCollectionView/AAPLTextValueDataSource.h>

// Layouts
#import <AdvancedCollectionView/AAPLCollectionViewLayout.h>
#import <AdvancedCollectionView/AAPLCollectionViewLayoutAttributes.h>
#import <AdvancedCollectionView/AAPLLayoutMetrics.h>

// View Controllers
#import <AdvancedCollectionView/AAPLCollectionViewController.h>

// Views
#import <AdvancedCollectionView/AAPLBasicCell.h>
#import <AdvancedCollectionView/AAPLCollectionViewCell.h>
#import <AdvancedCollectionView/AAPLHairlineView.h>
#import <AdvancedCollectionView/AAPLKeyValueCell.h>
#import <AdvancedCollectionView/AAPLLabel.h>
#import <AdvancedCollectionView/AAPLPinnableHeaderView.h>
#import <AdvancedCollectionView/AAPLPlaceholderView.h>
#import <AdvancedCollectionView/AAPLSectionHeaderView.h>
#import <AdvancedCollectionView/AAPLSegmentedHeaderView.h>
#import <AdvancedCollectionView/AAPLTextValueCell.h>

// Categories
#import <AdvancedCollectionView/AAPLDataSource+Headers.h>
#import <AdvancedCollectionView/UICollectionView+SupplementaryViews.h>
#import <AdvancedCollectionView/UIView+Helpers.h>

// Utilities
#import <AdvancedCollectionView/AAPLAction.h>
#import <AdvancedCollectionView/AAPLContentLoading.h>
#import <AdvancedCollectionView/AAPLStateMachine.h>
#import <AdvancedCollectionView/AAPLTheme.h>
