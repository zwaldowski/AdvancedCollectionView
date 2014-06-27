/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A pinnable header subclass of UICollectionReusableView.
  
 */

#import <UIKit/UIKit.h>

/// A base class for headers that can respond to being pinned to the top of the collection view
@interface AAPLPinnableHeaderView : UICollectionReusableView

/// Set when tracking a touch in the header. This can be used to mimic a cell as a header. If you don't know WHY you might want to do this, you probably don't.
@property (nonatomic) BOOL highlighted;

/// Default padding values preferred by the header/footer view.
@property (nonatomic, readonly) UIEdgeInsets defaultPadding;

/// Padding specified by the configuration. Can be used to update constraints.
@property (nonatomic) UIEdgeInsets padding;

/// Property updated by the collection view grid layout when the header is pinned to the top of the collection view.
@property (nonatomic, readonly) BOOL pinned;

/// The color of the bottom border. If nil, the bottom border is not shown. Default is 204,204,204.
@property (nonatomic, strong) UIColor *bottomBorderColor;

/// The color of the border to add to the header when it is pinned. A nil value indicates no border should be added.
@property (nonatomic, strong) UIColor *bottomBorderColorWhenPinned;

/// The background color to display when the header has been pinned. A nil value indicates the header should blend with navigation bars.
@property (nonatomic, strong) UIColor *backgroundColorWhenPinned;

/// Subclasses must call super to ensure correct updating of the pinned property
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes NS_REQUIRES_SUPER;

@end
