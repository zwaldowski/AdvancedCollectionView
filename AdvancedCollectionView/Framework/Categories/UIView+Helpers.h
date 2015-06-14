/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A category to add a simple method to send an action up the responder chain.
 */

@import UIKit;

NS_ASSUME_NONNULL_BEGIN




@interface UIView (Helpers)
/// Send an action up the responder chain.
- (BOOL)aapl_sendAction:(SEL)action;
@end




NS_ASSUME_NONNULL_END
