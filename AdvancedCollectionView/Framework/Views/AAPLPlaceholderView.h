/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Various placeholder views.
 */

@import UIKit;


/// A placeholder view that approximates the standard iOS no content view.
@interface AAPLPlaceholderView : UIView

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *buttonTitle;
@property (nonatomic, copy) void (^buttonAction)(void);

/// Initialize a placeholder view. A message is required in order to display a button.
- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title message:(NSString *)message image:(UIImage *)image buttonTitle:(NSString *)buttonTitle buttonAction:(dispatch_block_t)buttonAction NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@end

/// A placeholder view for use in the collection view. This placeholder includes the loading indicator.
@interface AAPLCollectionPlaceholderView : UICollectionReusableView

- (void)showActivityIndicator:(BOOL)show;
- (void)showPlaceholderWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image animated:(BOOL)animated;
- (void)hidePlaceholderAnimated:(BOOL)animated;

@end
