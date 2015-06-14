/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 AAPLLoadableContentStateMachine — This is the state machine that manages transitions for all loadable content.
  AAPLLoading — This is a signalling object used to simplify transitions on the statemachine and provide update blocks.
  AAPLContentLoading — A protocol adopted by the AAPLDataSource class for loading content.
 */

#import "AAPLContentLoading.h"
#import <libkern/OSAtomic.h>

#define DEBUG_AAPLLOADING 0

NSString * const AAPLLoadStateInitial = @"Initial";
NSString * const AAPLLoadStateLoadingContent = @"LoadingState";
NSString * const AAPLLoadStateRefreshingContent = @"RefreshingState";
NSString * const AAPLLoadStateContentLoaded = @"LoadedState";
NSString * const AAPLLoadStateNoContent = @"NoContentState";
NSString * const AAPLLoadStateError = @"ErrorState";


@implementation AAPLLoadableContentStateMachine

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.validTransitions = @{
                              AAPLLoadStateInitial : @[AAPLLoadStateLoadingContent],
                              AAPLLoadStateLoadingContent : @[AAPLLoadStateContentLoaded, AAPLLoadStateNoContent, AAPLLoadStateError],
                              AAPLLoadStateRefreshingContent : @[AAPLLoadStateContentLoaded, AAPLLoadStateNoContent, AAPLLoadStateError],
                              AAPLLoadStateContentLoaded : @[AAPLLoadStateRefreshingContent, AAPLLoadStateNoContent, AAPLLoadStateError],
                              AAPLLoadStateNoContent : @[AAPLLoadStateRefreshingContent, AAPLLoadStateContentLoaded, AAPLLoadStateError],
                              AAPLLoadStateError : @[AAPLLoadStateLoadingContent, AAPLLoadStateRefreshingContent, AAPLLoadStateNoContent, AAPLLoadStateContentLoaded]
                              };
    self.currentState = AAPLLoadStateInitial;
    return self;
}

@end



@interface AAPLLoadingProgress()
@property (nonatomic, readwrite, getter = isCancelled) BOOL cancelled;
@property (nonatomic, copy) void (^block)(NSString *newState, NSError *error, AAPLLoadingUpdateBlock update);
@end

@implementation AAPLLoadingProgress
#if DEBUG
{
    int32_t _complete;
}
#endif

+ (instancetype)loadingProgressWithCompletionHandler:(void(^)(NSString *state, NSError *error, AAPLLoadingUpdateBlock update))handler
{
    NSParameterAssert(handler != nil);
    AAPLLoadingProgress *loading = [[self alloc] init];
    loading.block = handler;
    loading.cancelled = NO;
    return loading;
}

#if DEBUG
- (void)aaplLoadingDebugDealloc
{
    if (OSAtomicCompareAndSwap32(0, 1, &_complete)) {
#if DEBUG_AAPLLOADING
        NSAssert(false, @"No completion methods called on AAPLLoading instance before dealloc called.");
#endif
        NSLog(@"No completion methods called on AAPLLoading instance before dealloc called. Break in -[AAPLLoading aaplLoadingDebugDealloc] to debug this.");
    }
}

- (void)dealloc
{
    // make this easier to debug by having a separate method for a breakpoint.
    [self aaplLoadingDebugDealloc];
}
#endif

- (void)doneWithNewState:(NSString *)newState error:(NSError *)error update:(AAPLLoadingUpdateBlock)update
{
#if DEBUG
    if (!OSAtomicCompareAndSwap32(0, 1, &_complete))
        NSAssert(false, @"completion method called more than once");
#endif

    void (^block)(NSString *state, NSError *error, AAPLLoadingUpdateBlock update) = _block;

    dispatch_async(dispatch_get_main_queue(), ^{
        block(newState, error, update);
    });

    _block = nil;
}

- (void)setCancelled:(BOOL)cancelled
{
    _cancelled = cancelled;
    // When cancelled, we immediately ignore the result of this loading operation. If one of the completion methods is called in DEBUG mode, we'll get an assertion.
    if (cancelled)
        [self ignore];
}

- (void)ignore
{
    [self doneWithNewState:nil error:nil update:nil];
}

- (void)done
{
    [self doneWithNewState:AAPLLoadStateContentLoaded error:nil update:nil];
}

- (void)updateWithContent:(AAPLLoadingUpdateBlock)update
{
    [self doneWithNewState:AAPLLoadStateContentLoaded error:nil update:update];
}

- (void)doneWithError:(NSError *)error
{
    NSString *newState = error ? AAPLLoadStateError : AAPLLoadStateContentLoaded;
    [self doneWithNewState:newState error:error update:nil];
}

- (void)updateWithNoContent:(AAPLLoadingUpdateBlock)update
{
    [self doneWithNewState:AAPLLoadStateNoContent error:nil update:update];
}
@end

