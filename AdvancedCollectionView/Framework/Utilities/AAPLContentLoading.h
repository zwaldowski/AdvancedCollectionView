/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 AAPLLoadableContentStateMachine — This is the state machine that manages transitions for all loadable content.
  AAPLLoading — This is a signalling object used to simplify transitions on the statemachine and provide update blocks.
  AAPLContentLoading — A protocol adopted by the AAPLDataSource class for loading content.
 */

#import "AAPLStateMachine.h"

NS_ASSUME_NONNULL_BEGIN




/// The initial state.
extern NSString *const AAPLLoadStateInitial;

/// The first load of content.
extern NSString *const AAPLLoadStateLoadingContent;

/// Subsequent loads after the first.
extern NSString *const AAPLLoadStateRefreshingContent;

/// After content is loaded successfully.
extern NSString *const AAPLLoadStateContentLoaded;

/// No content is available.
extern NSString *const AAPLLoadStateNoContent;

/// An error occurred while loading content.
extern NSString *const AAPLLoadStateError;




/// A block that performs updates on the object that is loading. The object parameter is the receiver of the `-loadContentWithProgress:` message.
typedef void (^AAPLLoadingUpdateBlock)(id object);




/** A specialization of AAPLStateMachine for content loading.

 The valid transitions for AAPLLoadableContentStateMachine are the following:

 - AAPLLoadStateInitial → AAPLLoadStateLoadingContent
 - AAPLLoadStateLoadingContent → AAPLLoadStateContentLoaded, AAPLLoadStateNoContent, or AAPLLoadStateError
 - AAPLLoadStateRefreshingContent → AAPLLoadStateContentLoaded, AAPLLoadStateNoContent, or AAPLLoadStateError
 - AAPLLoadStateContentLoaded → AAPLLoadStateRefreshingContent, AAPLLoadStateNoContent, or AAPLLoadStateError
 - AAPLLoadStateNoContent → AAPLLoadStateRefreshingContent, AAPLLoadStateContentLoaded or AAPLLoadStateError
 - AAPLLoadStateError → AAPLLoadStateLoadingContent, AAPLLoadStateRefreshingContent, AAPLLoadStateNoContent, or AAPLLoadStateContentLoaded

 The primary difference between `AAPLLoadStateLoadingContent` and `AAPLLoadStateRefreshingContent` is whether or not the owner had content to begin with. Refreshing content implies there was content already loaded and it just needed to be refreshed. This might require a different presentation (no loading indicator for example) than loading content for the first time.
 */
@interface AAPLLoadableContentStateMachine : AAPLStateMachine
@end



/** A class passed to the `-loadContentWithProgress:` method of an object adopting the `AAPLContentLoading` protocol.

 Implementers of `-loadContentWithProgress:` can use this object to signal the success or failure of the loading operation as well as the next state for their data source.
 */
@interface AAPLLoadingProgress : NSObject
/// Signals that this result should be ignored. Sends a nil value for the state to the completion handler.
- (void)ignore;
/// Signals that loading is complete with no errors. This triggers a transition to the Loaded state.
- (void)done;
/// Signals that loading failed with an error. This triggers a transition to the Error state.
- (void)doneWithError:(NSError *)error;
/// Signals that loading is complete, transitions into the Loaded state and then runs the update block.
- (void)updateWithContent:(AAPLLoadingUpdateBlock)update;
/// Signals that loading completed with no content, transitions to the No Content state and then runs the update block.
- (void)updateWithNoContent:(AAPLLoadingUpdateBlock)update;

/// Has this loading operation been cancelled? It's important to check whether the loading progress has been cancelled before calling one of the completion methods (-ignore, -done, -doneWithError:, updateWithContent:, or -updateWithNoContent:). When loading has been cancelled, updating via a completion method will throw an assertion in DEBUG mode.
@property (nonatomic, readonly, getter = isCancelled) BOOL cancelled;

/// create a new loading helper
+ (instancetype)loadingProgressWithCompletionHandler:(void(^)(__nullable NSString *state, __nullable NSError *error, __nullable AAPLLoadingUpdateBlock update))handler;

@end




/// A protocol that defines content loading behavior
@protocol AAPLContentLoading <NSObject>
/// The current state of the content loading operation
@property (nonatomic, copy) NSString *loadingState;
/// Any error that occurred during content loading. Valid only when loadingState == AAPLLoadStateError.
@property (nullable, nonatomic, strong) NSError *loadingError;

/// Public method used to begin loading the content.
- (void)loadContentWithProgress:(AAPLLoadingProgress *)progress;
/// Public method used to reset the content of the receiver.
- (void)resetContent;

@end




NS_ASSUME_NONNULL_END
