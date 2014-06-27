/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A simple object that represents an action that might be associated with a cell or used in a data source to present a series of buttons.
  
 */

#import "AAPLAction.h"

@interface AAPLAction ()
@property (nonatomic, readwrite, strong) NSString *title;
@property (nonatomic, readwrite) SEL selector;
@property (nonatomic, readwrite, getter = isDestructive) BOOL destructive;
@end

@implementation AAPLAction

+ (instancetype)actionWithTitle:(NSString *)title selector:(SEL)selector
{
    AAPLAction *action = [[self alloc] init];
    action.title = title;
    action.selector = selector;
    return action;
}

+ (instancetype)destructiveActionWithTitle:(NSString *)title selector:(SEL)selector
{
    AAPLAction *action = [[self alloc] init];
    action.title = title;
    action.selector = selector;
    action.destructive = YES;
    return action;
}

@end
