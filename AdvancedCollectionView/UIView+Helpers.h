/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A category to add a simple method to send an action up the responder chain.
  
 */

@import UIKit;

@interface UIView (Helpers)
- (BOOL)aapl_sendAction:(SEL)action from:(id)sender;

@property (nonatomic, readonly) CGFloat aapl_scale;
@property (nonatomic, readonly) CGFloat aapl_hairline;

@end
