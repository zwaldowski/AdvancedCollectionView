/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of UICollectionViewLayoutAttributes with additional attributes required by the AAPLCollectionViewGridLayout, AAPLCollectionViewCell, and AAPLPinnableHeaderView classes.
 
  This file defines some additional attributes that used for internal communication between the layout and cells. In most cases, alternate means of accessing this information exists.
 */

#import "AAPLCollectionViewLayoutAttributes.h"

NS_ASSUME_NONNULL_BEGIN




@class AAPLTheme;

@interface AAPLCollectionViewLayoutAttributes ()
/// What is the column index for this item?
@property (nonatomic) NSInteger columnIndex;
/// Is the layout in edit mode
@property (nonatomic, getter = isEditing) BOOL editing;
/// Is the cell movable according to the data source. Only YES when editing
@property (nonatomic, getter = isMovable) BOOL movable;

/// The color for a header/footer that's been pinned
@property (nonatomic, strong) UIColor *pinnedBackgroundColor;

/// The color for the header/footer separator.
@property (nonatomic, strong) UIColor *separatorColor;

/// The color for a separator of a header/footer that's been pinned
@property (nonatomic, strong) UIColor *pinnedSeparatorColor;

/// Should the header/footer show its separator line
@property (nonatomic) BOOL showsSeparator;

/// Whether the header should simulate selection
@property (nonatomic) BOOL simulatesSelection;

/// Y offset when not pinned
@property (nonatomic) CGFloat unpinnedY;

/// The theme we're passing to the cell or supplementary view
@property (nonatomic, strong) AAPLTheme *theme;

/// Whether the correct fitting size should be calculated in -preferredLayoutAttributesFittingAttributes: or if the value is already correct.
@property (nonatomic) BOOL shouldCalculateFittingSize;

@end




NS_ASSUME_NONNULL_END
