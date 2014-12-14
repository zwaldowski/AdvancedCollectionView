/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A category to add a simple method to send an action up the responder chain.
  
 */

#import "UIView+Helpers.h"

@implementation UIView (Helpers)

- (BOOL)aapl_sendAction:(SEL)action from:(id)sender
{
    // Get the target in the responder chain
    id target = sender;

    while (target && ![target canPerformAction:action withSender:sender]) {
        target = [target nextResponder];
    }

    if (!target)
        return NO;

    return [[UIApplication sharedApplication] sendAction:action to:target from:sender forEvent:nil];
}

// This is a dupe of -[UIView _currentScreenScale].
- (CGFloat)aapl_scale
{
    UIScreen *screen = self.window.screen ?: UIScreen.mainScreen;
    return screen.scale;
}

- (CGFloat)aapl_hairline
{
    return 1 / self.aapl_scale;
}

@end
