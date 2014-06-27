/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A general purpose state machine implementation. The state machine will call methods on the delegate based on the name of the state. For example, when transitioning from StateA to StateB, the state machine will first call -shouldEnterStateA. If that method isn't implemented or returns YES, the state machine updates the current state. It then calls -didExitStateA followed by -didEnterStateB. Finally, if implemented, it will call -stateDidChange.
  Assumptions:
     • The number of states and transitions are relatively few
     • State transitions are relatively infrequent
     • Multithreadsafety/atomicity is handled at a higher level
  
 */

#import "AAPLStateMachine.h"

#import <objc/message.h>
#import <libkern/OSAtomic.h>

static NSString * const AAPLStateNil = @"Nil";

@implementation AAPLStateMachine {
    OSSpinLock _lock;
}

@synthesize currentState = _currentState;

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _lock = OS_SPINLOCK_INIT;

    return self;
}

- (id)target
{
    id<AAPLStateMachineDelegate> delegate = self.delegate;
    if (delegate)
        return delegate;
    return self;
}

- (NSString *)currentState
{
    __block NSString *currentState;
    
    // for atomic-safety, _currentState must not be released between the load of _currentState and the retain invocation
    OSSpinLockLock(&_lock);
    currentState = _currentState;
    OSSpinLockUnlock(&_lock);
    
    return currentState;
}

- (BOOL)applyState:(NSString *)toState
{
    return [self _setCurrentState:toState];
}

- (void)setCurrentState:(NSString *)toState
{
    [self _setCurrentState:toState];
}

- (BOOL)_setCurrentState:(NSString *)toState
{
    NSString *fromState = self.currentState;
       
    if (self.shouldLogStateTransitions)
        NSLog(@" ••• request state change from %@ to %@", fromState, toState);

    NSString *appliedToState = [self _validateTransitionFromState:fromState toState:toState];
    if (!appliedToState)
        return NO;

    // ...send will-change message for downstream KVO support...
    id target = [self target];

    SEL genericWillChangeAction = @selector(stateWillChange);
    if ([target respondsToSelector:genericWillChangeAction]) {
        typedef void (*ObjCMsgSendReturnVoid)(id, SEL);
        ObjCMsgSendReturnVoid sendMsgReturnVoid = (ObjCMsgSendReturnVoid)objc_msgSend;
        sendMsgReturnVoid(target, genericWillChangeAction);
    }
    
    OSSpinLockLock(&_lock);
    _currentState = [appliedToState copy];
    OSSpinLockUnlock(&_lock);
    
    // ... send messages
    [self _performTransitionFromState:fromState toState:appliedToState];

    return [toState isEqual:appliedToState];
}

- (NSString *)_missingTransitionFromState:(NSString *)fromState toState:(NSString *)toState
{
    if ([_delegate respondsToSelector:@selector(missingTransitionFromState:toState:)])
        return [_delegate missingTransitionFromState:fromState toState:toState];
    return [self missingTransitionFromState:fromState toState:toState];
}

- (NSString *)missingTransitionFromState:(NSString *)fromState toState:(NSString *)toState
{
    [NSException raise:@"IllegalStateTransition" format:@"cannot transition from %@ to %@", fromState, toState];
    return nil;
}

- (NSString *)_validateTransitionFromState:(NSString *)fromState toState:(NSString *)toState
{
    // Transitioning to the same state (fromState == toState) is always allowed. If it's explicitly included in its own validTransitions, the standard method calls below will be invoked. This allows us to avoid creating states that exist only to reexecute transition code for the current state.

    // Raise exception if attempting to transition to nil -- you can only transition *from* nil
    if (!toState) {
        NSLog(@"  ••• %@ cannot transition to <nil> state", self);
        toState = [self _missingTransitionFromState:fromState toState:toState];
        if (!toState) {
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
                if (self.shouldLogStateTransitions)
                    NSLog(@"  ••• %@ ignoring reentry to %@", self, toState);
                return nil;
            }
            
            if (self.shouldLogStateTransitions)
                NSLog(@"  ••• %@ cannot transition to %@ from %@", self, toState, fromState);
            toState = [self _missingTransitionFromState:fromState toState:toState];
            if (!toState)
                return nil;
        }
    }
    
    // Allow target to opt out of this transition (preconditions)
    id target = [self target];
    typedef BOOL (*ObjCMsgSendReturnBool)(id, SEL);
    ObjCMsgSendReturnBool sendMsgReturnBool = (ObjCMsgSendReturnBool)objc_msgSend;
    
    SEL enterStateAction = NSSelectorFromString([@"shouldEnter" stringByAppendingString:toState]);
    if ([target respondsToSelector:enterStateAction] && !sendMsgReturnBool(target, enterStateAction)) {
        NSLog(@"  ••• %@ transition disallowed to %@ from %@ (via %@)", self, toState, fromState, NSStringFromSelector(enterStateAction));
        toState = [self _missingTransitionFromState:fromState toState:toState];
    }

    return toState;
}

- (void)_performTransitionFromState:(NSString *)fromState toState:(NSString *)toState
{
    // Subclasses may implement several different selectors to handle state transitions:
    //
    //  did enter state (didEnterPaused)
    //  did exit state (didExitPaused)
    //  transition between states (stateDidChangeFromPausedToPlaying)
    //  generic transition handler (stateDidChange), for common tasks
    //
    // Any and all of these that are implemented will be invoked.

    if (self.shouldLogStateTransitions)
        NSLog(@"  ••• %@ state change from %@ to %@", self, fromState, toState);

    id target = [self target];
    
    typedef void (*ObjCMsgSendReturnVoid)(id, SEL);
    ObjCMsgSendReturnVoid sendMsgReturnVoid = (ObjCMsgSendReturnVoid)objc_msgSend;

    if (fromState) {
        SEL exitStateAction = NSSelectorFromString([@"didExit" stringByAppendingString:fromState]);
        if ([target respondsToSelector:exitStateAction]) {
            sendMsgReturnVoid(target, exitStateAction);
        }
    }

    SEL enterStateAction = NSSelectorFromString([@"didEnter" stringByAppendingString:toState]);
    if ([target respondsToSelector:enterStateAction]) {
        sendMsgReturnVoid(target, enterStateAction);
    }
    
    NSString *fromStateNotNil = fromState ? fromState : AAPLStateNil;
    
    SEL transitionAction = NSSelectorFromString([NSString stringWithFormat:@"stateDidChangeFrom%@To%@", fromStateNotNil, toState]);
    if ([target respondsToSelector:transitionAction]) {
        sendMsgReturnVoid(target, transitionAction);
    }

    SEL genericDidChangeAction = @selector(stateDidChange);
    if ([target respondsToSelector:genericDidChangeAction]) {
        sendMsgReturnVoid(target, genericDidChangeAction);
    }
}

@end
