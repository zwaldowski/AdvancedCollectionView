/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of UICollectionViewLayoutAttributes with additional attributes required by the AAPLCollectionViewGridLayout, AAPLCollectionViewCell, and AAPLPinnableHeaderView classes.
  
 */

@import UIKit;

@interface AAPLCollectionViewGridLayoutAttributes : UICollectionViewLayoutAttributes
/// If this is a header, is it pinned to the top of the collection view?
@property (nonatomic, getter = isPinnedHeader) BOOL pinnedHeader;
/// The background color for the view
@property (nonatomic, strong) UIColor *backgroundColor;
/// The background color when selected
@property (nonatomic, strong) UIColor *selectedBackgroundColor;
/// Used by supplementary items
@property (nonatomic) UIEdgeInsets padding;
@end

/// A subclass of UICollectionViewLayoutInvalidationContext that adds invalidation for metrics and origin
@interface AAPLGridLayoutInvalidationContext : UICollectionViewLayoutInvalidationContext
@property (nonatomic) BOOL invalidateLayoutMetrics;
@property (nonatomic) BOOL invalidateLayoutOrigin;
@end
