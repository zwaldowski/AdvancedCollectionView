/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of UICollectionViewLayoutAttributes with additional attributes required by the AAPLCollectionViewGridLayout, AAPLCollectionViewCell, and AAPLPinnableHeaderView classes.
 */

@import UIKit;

NS_ASSUME_NONNULL_BEGIN




/// Custom Layout Attributes for the Layout.
@interface AAPLCollectionViewLayoutAttributes : UICollectionViewLayoutAttributes
/// If this is a header, is it pinned to the top of the collection view?
@property (nonatomic, getter = isPinnedHeader) BOOL pinnedHeader;
/// The background color for the view
@property (nonatomic, strong) UIColor *backgroundColor;
/// The background color when selected
@property (nonatomic, strong) UIColor *selectedBackgroundColor;
/// Layout margins passed to cells and supplementary views
@property (nonatomic) UIEdgeInsets layoutMargins;
@end




NS_ASSUME_NONNULL_END
