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

#import <Foundation/Foundation.h>

@protocol AAPLStateMachineDelegate <NSObject>

@optional

// Completely generic state change hook
- (void)stateWillChange;
- (void)stateDidChange;

/// Return the new state or nil for no change for an missing transition from a state to another state. If implemented, overrides the base implementation completely.
- (NSString *)missingTransitionFromState:(NSString *)fromState toState:(NSString *)toState;

@end

@interface AAPLStateMachine : NSObject

@property (copy, atomic) NSString *currentState;
@property (retain, atomic) NSDictionary *validTransitions;

/// If set, AAPLStateMachine invokes transition methods on this delegate instead of self. This allows AAPLStateMachine to be used where subclassing doesn't make sense. The delegate is invoked on the same thread as -setCurrentState:
@property (weak, atomic) id<AAPLStateMachineDelegate> delegate;

/// use NSLog to output state transitions; useful for debugging, but can be noisy
@property (assign, nonatomic) BOOL shouldLogStateTransitions;

/// set current state and return YES if the state changed successfully to the supplied state, NO otherwise. Note that this does _not_ bypass missingTransitionFromState, so, if you invoke this, you must also supply an missingTransitionFromState implementation that avoids raising exceptions.
- (BOOL)applyState:(NSString *)state;

/// For subclasses. Base implementation raises IllegalStateTransition exception. Need not invoke super unless desired. Should return the desired state if it doesn't raise, or nil for no change.
- (NSString *)missingTransitionFromState:(NSString *)fromState toState:(NSString *)toState;

@end

