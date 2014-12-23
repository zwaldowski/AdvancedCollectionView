/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of UICollectionViewLayoutAttributes with additional attributes required by the AAPLCollectionViewGridLayout, AAPLCollectionViewCell, and AAPLPinnableHeaderView classes.
  
  This file defines some additional attributes that used for internal communication between the layout and cells. In most cases, alternate means of accessing this information exists.
  
 */

#import "AAPLCollectionViewGridLayoutAttributes.h"

@interface AAPLCollectionViewGridLayoutAttributes ()
/// What is the column index for this item?
@property (nonatomic) NSInteger columnIndex;

/// Y offset when not pinned
@property (nonatomic) CGFloat unpinnedY;

@end


