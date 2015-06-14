/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A pinnable header subclass of UICollectionReusableView.
 */

@import UIKit;

NS_ASSUME_NONNULL_BEGIN




@class AAPLTheme;

/// A base class for headers that respond to being pinned to the top of the collection view.
@interface AAPLPinnableHeaderView : UICollectionReusableView

/// Set when tracking a touch in the header. This can be used to mimic a cell as a header. If you don't know WHY you might want to do this, you probably don't.
@property (nonatomic, getter = isHighlighted) BOOL highlighted;

/// Default padding values preferred by the header/footer view.
@property (nonatomic, readonly) UIEdgeInsets defaultLayoutMargins;

/// Property updated by the collection view layout when the header is pinned to the top of the collection view.
@property (nonatomic, readonly, getter = isPinned) BOOL pinned;

/// Should this header/footer show a separator?
@property (nonatomic) BOOL showsSeparator;

/// The color of the bottom border. The default value is pulled from the theme.separatorColor value.
@property (nonatomic, strong) UIColor *separatorColor;

/// The color of the border to add to the header when it is pinned. When this property is nil, the separator will not change color when pinned.
@property (nonatomic, strong) UIColor *pinnedSeparatorColor;

/// The background color to display when the header has been pinned. A nil value indicates the header should blend with navigation bars.
@property (nonatomic, strong) UIColor *pinnedBackgroundColor;

/// The theme this header should use to resolve any values not specified in its attributes
@property (nonatomic, strong) AAPLTheme *theme;

/// Subclasses must call super to ensure correct updating of the pinned property
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes NS_REQUIRES_SUPER;

@end




NS_ASSUME_NONNULL_END
