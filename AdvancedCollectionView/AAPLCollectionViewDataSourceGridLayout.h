//
//  AAPLCollectionViewDataSourceGridLayout.h
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

@import UIKit;
#import "AAPLLayoutMetrics.h"

@class AAPLCollectionViewGridLayout;

@protocol AAPLCollectionViewDataSourceGridLayout <UICollectionViewDataSource>

/// Measure variable height cells. The goal here is to do the minimal necessary configuration to get the correct size information.
- (CGSize)collectionView:(UICollectionView *)collectionView sizeFittingSize:(CGSize)size forItemAtIndexPath:(NSIndexPath *)indexPath;

/// Measure variable height supplements. The goal here is to do the minimal necessary configuration to get the correct size information.
- (CGSize)collectionView:(UICollectionView *)collectionView sizeFittingSize:(CGSize)size forSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/// Compute a flattened snapshot of the layout metrics associated with this and any child data sources.
- (NSDictionary /*NSNumber:AAPLLayoutMetrics*/ *)snapshotMetrics;

@optional

/// Determine whether or not a cell is editable. Default implementation returns YES.
- (BOOL)collectionView:(UICollectionView *)collectionView canEditItemAtIndexPath:(NSIndexPath *)indexPath;

@end
