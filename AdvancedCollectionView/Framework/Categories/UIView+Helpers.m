/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A category to add a simple method to send an action up the responder chain.
 */

#import "UIView+Helpers.h"
@import ObjectiveC.message;

@implementation UIView (Helpers)

- (BOOL)aapl_sendAction:(SEL)action
{
    // Get the target in the responder chain
    id target = [self targetForAction:action withSender:self];
    
    if (target == nil)
        return NO;
    
    // Handle the 2-param recieveCallback(sender:event:) format.
    typedef void(*SendEvent)(id, SEL, id, id);
    SendEvent send = (SendEvent)objc_msgSend;
    send(target, action, self, nil);
    
    return YES;
}

@end
