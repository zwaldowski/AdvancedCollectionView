/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import <UIKit/UIKit.h>

#import "AAPLCollectionViewGridLayoutAttributes.h"

extern NSUInteger const AAPLGlobalSection;

extern NSString * const AAPLCollectionElementKindPlaceholder;

@interface AAPLCollectionViewGridLayout : UICollectionViewLayout

/// Recompute the layout for a specific item. This will remeasure the cell and then update the layout.
- (void)invalidateLayoutForItemAtIndexPath:(NSIndexPath *)indexPath;

@end
