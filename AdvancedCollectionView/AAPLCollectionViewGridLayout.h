/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
  
 */

@import UIKit;
#import "AAPLCollectionViewGridLayoutAttributes.h"
#import "AAPLCollectionViewDataSourceGridLayout.h"

@interface AAPLCollectionViewGridLayout : UICollectionViewLayout

/// Recompute the layout for a specific item. This will remeasure the cell and then update the layout.
- (void)invalidateLayoutForItemAtIndexPath:(NSIndexPath *)indexPath;

/// Recompute the layout for a global header.
- (void)invalidateLayoutForGlobalSection;

@end
