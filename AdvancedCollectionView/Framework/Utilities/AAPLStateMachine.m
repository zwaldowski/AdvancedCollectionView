/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
*/

#import "AAPLStateMachine.h"
#import <objc/message.h>
#import <libkern/OSAtomic.h>

static NSString *const AAPLStateNil = @"Nil";
NSString *const AAPLInvalidStateTransitionException = @"InvalidStateTransitionException";

@interface AAPLStateMachine () <AAPLStateMachineDelegate> {
	OSSpinLock _lock;
	__weak id<AAPLStateMachineDelegate> _delegate;
	NSString *_currentState;
	struct {
		BOOL targetRespondsToShouldChange;
		BOOL targetRespondsToWillChange;
		BOOL targetRespondsToDidChange;
		BOOL delegateRespondsToMissingTransition;
	} _flags;
}

@end

@implementation AAPLStateMachine

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _lock = OS_SPINLOCK_INIT;
	[self updateTargetResponds];

    return self;
}

- (id <AAPLStateMachineDelegate>)target
{
    id<AAPLStateMachineDelegate> delegate = self.delegate;
	if (delegate) { return delegate; }
    return self;
}

- (id<AAPLStateMachineDelegate>)delegate
{
	id<AAPLStateMachineDelegate> delegate = nil;
	
	// for atomic-safety, _currentState must not be released between the load of _currentState and the retain invocation
	OSSpinLockLock(&_lock);
	delegate = _delegate;
	OSSpinLockUnlock(&_lock);
	
	return delegate;
}

- (void)updateTargetResponds
{
	id<AAPLStateMachineDelegate> delegate = self.delegate;
	id<AAPLStateMachineDelegate> target = delegate ?: self;
	_flags.targetRespondsToShouldChange = [target respondsToSelector:@selector(shouldChangeToState:)];
	_flags.targetRespondsToWillChange = [target respondsToSelector:@selector(stateWillChangeFrom:to:)];
	_flags.targetRespondsToDidChange = [target respondsToSelector:@selector(stateWillChangeFrom:to:)];
	_flags.delegateRespondsToMissingTransition = [target respondsToSelector:@selector(missingTransitionFromState:toState:)];
}

- (void)setDelegate:(id<AAPLStateMachineDelegate>)delegate
{
	NSParameterAssert([delegate conformsToProtocol:@protocol(AAPLStateMachineDelegate)]);

	OSSpinLockLock(&_lock);
	_delegate = delegate;
	OSSpinLockUnlock(&_lock);
	
	[self updateTargetResponds];
}

- (NSString *)currentState
{
    NSString *currentState = nil;
    
    // for atomic-safety, _currentState must not be released between the load of _currentState and the retain invocation
    OSSpinLockLock(&_lock);
    currentState = _currentState;
    OSSpinLockUnlock(&_lock);
    
    return currentState;
}

- (void)setCurrentState:(NSString *)toState
{
	NSString *fromState = self.currentState;
	
	if ([fromState isEqual:toState]) {
		return;
	}
	
	NSString *appliedToState = [self validateTransitionFromState:fromState toState:toState];
	if (!appliedToState)
		return;
	
	// ...send will-change message for downstream KVO support...
	id <AAPLStateMachineDelegate> target = [self target];
	NSString *fromStateNotNil = fromState ? fromState : AAPLStateNil;
	
	if (_flags.targetRespondsToWillChange) {
		[target stateWillChangeFrom:fromStateNotNil to:appliedToState];
	}
	
	OSSpinLockLock(&_lock);
	_currentState = [appliedToState copy];
	OSSpinLockUnlock(&_lock);
	
	if (_flags.targetRespondsToDidChange) {
		[target stateDidChangeFrom:fromStateNotNil to:appliedToState];
	}
}

- (NSString *)validateMissingTransitionFromState:(NSString *)fromState toState:(NSString *)toState
{
    if (_flags.delegateRespondsToMissingTransition)
		return [self.delegate missingTransitionFromState:fromState toState:toState];
    return [self missingTransitionFromState:fromState toState:toState];
}

- (NSString *)missingTransitionFromState:(NSString *)fromState toState:(NSString *)toState
{
	@throw [NSException exceptionWithName:AAPLInvalidStateTransitionException reason:[NSString stringWithFormat:@"cannot transition from %@ to %@", fromState, toState] userInfo:nil];
}

- (NSString *)validateTransitionFromState:(NSString *)fromState toState:(NSString *)toState
{
    // Transitioning to the same state (fromState == toState) is always allowed. If it's explicitly included in its own validTransitions, the standard method calls below will be invoked. This allows us to avoid creating states that exist only to reexecute transition code for the current state.
	
    // Raise exception if attempting to transition to nil -- you can only transition *from* nil
    if (!toState) {
		if (!(toState = [self validateMissingTransitionFromState:fromState toState:toState])) {
			return nil;
		}
    }

    // Raise exception if this is an illegal transition (toState must be a validTransition on fromState)
    if (fromState) {
        id validTransitions = self.validTransitions[fromState];
        BOOL transitionSpecified = YES;
        
        // Multiple valid transitions
        if ([validTransitions isKindOfClass:[NSArray class]]) {
            if (![validTransitions containsObject:toState]) {
                transitionSpecified = NO;
            }
        }
        // Otherwise, single valid transition object
        else if (![validTransitions isEqual:toState]) {
            transitionSpecified = NO;
        }
        
        if (!transitionSpecified) {
            // Silently fail if implict transition to the same state
            if ([fromState isEqualToString:toState]) {
                return nil;
            }
            
            toState = [self validateMissingTransitionFromState:fromState toState:toState];
            if (!toState)
                return nil;
        }
    }
    
    // Allow target to opt out of this transition (preconditions)
	if (_flags.targetRespondsToShouldChange && ![self.target shouldChangeToState:toState]) {
		toState = [self validateMissingTransitionFromState:fromState toState:toState];
	}

    return toState;
}

@end
