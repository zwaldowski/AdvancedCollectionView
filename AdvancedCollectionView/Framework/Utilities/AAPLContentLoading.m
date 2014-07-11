/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLContentLoading.h"

NSString *const AAPLLoadStateInitial = @"Initial";
NSString *const AAPLLoadStateLoadingContent = @"LoadingState";
NSString *const AAPLLoadStateRefreshingContent = @"RefreshingState";
NSString *const AAPLLoadStateContentLoaded = @"LoadedState";
NSString *const AAPLLoadStateNoContent = @"NoContentState";
NSString *const AAPLLoadStateError = @"ErrorState";

@interface AAPLLoading ()

@property (nonatomic, copy) AAPLLoadingCompletionBlock block;

@end

@implementation AAPLLoading

- (instancetype)initWithCompletionHandler:(AAPLLoadingCompletionBlock)handler
{
	NSParameterAssert(handler != nil);
	self = [super init];
	if (!self) return nil;
	self.block = handler;
	self.current = YES;
	return self;
}

- (void)doneWithNewState:(NSString *)newState error:(NSError *)error update:(AAPLLoadingUpdateBlock)update
{
	AAPLLoadingCompletionBlock block = self.block;
	self.block = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        block(newState, error, update);
    });
}

- (void)ignore
{
    [self doneWithNewState:nil error:nil update:NULL];
}

- (void)updateWithContent:(AAPLLoadingUpdateBlock)update
{
    [self doneWithNewState:AAPLLoadStateContentLoaded error:nil update:update];
}

- (void)done:(BOOL)success error:(NSError *)error
{
	NSString *newState = success ? AAPLLoadStateContentLoaded : AAPLLoadStateError;
	[self doneWithNewState:newState error:error update:NULL];
}

- (void)updateWithNoContent:(AAPLLoadingUpdateBlock)update
{
    [self doneWithNewState:AAPLLoadStateNoContent error:nil update:update];
}

@end

@implementation AAPLStateMachine (AAPLLoadableContentStateMachine)

+ (instancetype)loadableContentStateMachine
{
	AAPLStateMachine *sm = [[AAPLStateMachine alloc] init];
    sm.currentState = AAPLLoadStateInitial;
    sm.validTransitions = @{
        AAPLLoadStateInitial : @[AAPLLoadStateLoadingContent],
        AAPLLoadStateLoadingContent : @[AAPLLoadStateContentLoaded, AAPLLoadStateNoContent, AAPLLoadStateError],
        AAPLLoadStateRefreshingContent : @[AAPLLoadStateContentLoaded, AAPLLoadStateNoContent, AAPLLoadStateError],
        AAPLLoadStateContentLoaded : @[AAPLLoadStateRefreshingContent, AAPLLoadStateNoContent, AAPLLoadStateError],
        AAPLLoadStateNoContent : @[AAPLLoadStateRefreshingContent, AAPLLoadStateContentLoaded, AAPLLoadStateError],
        AAPLLoadStateError : @[AAPLLoadStateLoadingContent, AAPLLoadStateRefreshingContent, AAPLLoadStateNoContent, AAPLLoadStateContentLoaded]
    };
    return sm;
}

@end
