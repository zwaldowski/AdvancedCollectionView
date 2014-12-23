/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A state machine that manages a a UIPanGestureRecognizer to handle swipe to edit.
  
 */

#define DEBUG_SWIPE_TO_EDIT 0

#if DEBUG_SWIPE_TO_EDIT
#define SWIPE_LOG(FORMAT, ...) NSLog(@"»%@ " FORMAT, NSStringFromSelector(_cmd), __VA_ARGS__)
#else
#define SWIPE_LOG(FORMAT, ...)
#endif

#import "AAPLSwipeToEditStateMachine.h"
#import "AAPLCollectionViewCell_Private.h"
#import "AAPLCollectionViewGridLayout_Private.h"
#import "AAPLDataSource.h"
@import Darwin.libkern.OSAtomic;

typedef int32_t aapl_debounce_t;

void aapl_debounce(aapl_debounce_t *predicate, dispatch_block_t block)
{
    if (OSAtomicCompareAndSwap32(0, 1, predicate)) {
        block();
        OSAtomicDecrement32(predicate);
    }
}



NSString * const AAPLSwipeStateNothing = @"NothingState";
NSString * const AAPLSwipeStateEditing = @"EditingState";
NSString * const AAPLSwipeStateTracking = @"TrackingState";
NSString * const AAPLSwipeStateAnimatingOpen = @"AnimatingOpenState";
NSString * const AAPLSwipeStateAnimatingShut = @"AnimatingShutState";
NSString * const AAPLSwipeStateGroupEdit = @"GroupEdit";

#define REMOVE_CONTROL_EDGE_INSETS UIEdgeInsetsMake(-15, -15, -15, -15)

@interface AAPLCancelSwipeToEditGestureRecognizer : UITapGestureRecognizer

@property (nonatomic, retain) AAPLCollectionViewCell *currentEditingCell; // rect where this gesture recognizer does not work within the owning view coordinate space

@end

@interface AAPLSwipeToEditStateMachine ()
{
    aapl_debounce_t _debounce;
}

@property (nonatomic, strong) UICollectionView *collectionView;

@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, strong) AAPLCollectionViewCell *editingCell;
@property (nonatomic) CGFloat startTrackingX;

@end

@implementation AAPLSwipeToEditStateMachine

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView
{
    self = [super init];
    if (!self)
        return nil;

    self.collectionView = collectionView;

    self.currentState = AAPLSwipeStateNothing;
    self.validTransitions = @{
                              AAPLSwipeStateNothing : @[AAPLSwipeStateTracking, AAPLSwipeStateAnimatingOpen],
                              AAPLSwipeStateTracking : @[AAPLSwipeStateAnimatingOpen, AAPLSwipeStateAnimatingShut, AAPLSwipeStateTracking, AAPLSwipeStateNothing],
                              AAPLSwipeStateAnimatingOpen : @[AAPLSwipeStateEditing, AAPLSwipeStateAnimatingShut, AAPLSwipeStateTracking, AAPLSwipeStateNothing],
                              AAPLSwipeStateAnimatingShut : @[AAPLSwipeStateNothing],
                              AAPLSwipeStateEditing : @[AAPLSwipeStateTracking, AAPLSwipeStateAnimatingShut, AAPLSwipeStateNothing]
                              };

    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    _panGestureRecognizer.delegate = self;

    for (UIGestureRecognizer *recognizer in _collectionView.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]])
            [recognizer requireGestureRecognizerToFail:_panGestureRecognizer];
    }

    [collectionView addGestureRecognizer:_panGestureRecognizer];

    return self;
}

- (void)setBatchEditing:(BOOL)batchEditing
{
    if (_batchEditing == batchEditing)
        return;
    
    if (_editingCell)
        [self shutActionPaneForEditingCellAnimated:NO];
    _batchEditing = batchEditing;
}

- (NSIndexPath *)trackedIndexPath
{
    return [_collectionView indexPathForCell:_editingCell];
}

- (void)setDelegate:(id<AAPLStateMachineDelegate>)delegate
{
    NSAssert(NO, @"you're not the boss of me");
}

#if DEBUG_SWIPE_TO_EDIT
- (void)setCurrentState:(NSString *)currentState
{
    SWIPE_LOG(@"%@", currentState);
    [super setCurrentState:currentState];
}
#endif

- (void)setEditingCell:(AAPLCollectionViewCell *)editingCell
{
    if (_editingCell == editingCell)
        return;
    _editingCell = editingCell;
}

- (CGFloat)xPositionForTranslation:(CGPoint)translation
{
    return fmin(0, _startTrackingX + translation.x);
}

- (void)shutActionPaneForEditingCellAnimated:(BOOL)animate
{
    // our cancel gesture recognizer comes through this code path, and should normally cause the edit pane to slide shut except for when some control on screen, like a segmented control, triggers the pane to slide shut without animation. in that case, we need to preempt any animation with a debounce.
    if (animate) {
        // the segmented datasource might have changed in the same event loop, so delay this one loop cycle later
        dispatch_async(dispatch_get_main_queue(), ^{
            aapl_debounce(&self->_debounce, ^{
                // somebody might have already shut us by the time we're called, so only shut if we're not already
                if (![self.currentState isEqualToString:AAPLSwipeStateNothing]) {
                    self.currentState = AAPLSwipeStateAnimatingShut;
                    [self.editingCell closeActionPaneAnimated:YES completionHandler:^(BOOL finished) {
                        if (finished) {
                            self.currentState = AAPLSwipeStateNothing;
                        }
                    }];
                }
            });
        });
    }
    else {
        aapl_debounce(&_debounce, ^{
            [self.editingCell closeActionPaneAnimated:NO completionHandler:nil];
            self.currentState = AAPLSwipeStateNothing;
        });
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    if (![self.currentState isEqualToString:AAPLSwipeStateNothing]) {
        [self shutActionPaneForEditingCellAnimated:NO];
    }
}

#pragma mark - Gesture Recognizer action methods

- (void)handlePan:(UIPanGestureRecognizer *)recognizer
{
    if (_batchEditing) {
        return;
    }
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            break;
        }
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [recognizer translationInView:_editingCell];
            CGFloat xPosition = [self xPositionForTranslation:translation];
            _editingCell.swipeTrackingPosition = xPosition;
            self.currentState = AAPLSwipeStateTracking;

            break;
        }
        case UIGestureRecognizerStateEnded:
        {
            CGFloat velocityX = [recognizer velocityInView:_editingCell].x;

            CGFloat xPosition = _editingCell.swipeTrackingPosition;
            CGFloat targetX = _editingCell.minimumSwipeTrackingPosition;
            CGPoint translatedPoint = [recognizer translationInView:_editingCell];

            double threshhold = 100.0;
            if (velocityX < 0 && (-velocityX > threshhold || xPosition <= targetX)) {
                CGFloat adjVelocityX = (0.2f * [recognizer velocityInView:_editingCell].x);

                CGFloat finalX = translatedPoint.x + adjVelocityX;

                if (UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation])) {
                    if (finalX < 0) {
                        //finalX = 0;
                    } else if (finalX > 768) {
                        //finalX = 768;
                    }
                } else {
                    if (finalX < 0) {
                        //finalX = 0;
                    } else if (finalX > 1024) {
                        //finalX = 768;
                    }

                }

                finalX = fmax(targetX, finalX);
                CGFloat animationDuration = (fabs(velocityX)*.0002)+.2;

                self.currentState = AAPLSwipeStateAnimatingOpen;
                [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    self.editingCell.swipeTrackingPosition = finalX;
                } completion:^(BOOL finished) {
                    // Only set it to editing if we're still in the same state as we previously set. It can change if that devilish user keeps fiddling with things.
                    if ([AAPLSwipeStateAnimatingOpen isEqualToString:self.currentState])
                        self.currentState = AAPLSwipeStateEditing;
                }];
            }
            else {
                [self shutActionPaneForEditingCellAnimated:YES];
            }
            break;
        }
        case UIGestureRecognizerStateCancelled:
        {
            [self shutActionPaneForEditingCellAnimated:YES];
            break;
        }
        default:
            break;
    }
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer
{
    if (_batchEditing && [self.currentState isEqualToString:AAPLSwipeStateNothing]) {
        self.currentState = AAPLSwipeStateAnimatingOpen;
        [_editingCell openActionPaneAnimated:YES completionHandler:^(BOOL finished){
            // Only set it to editing if we're still in the same state as we previously set. It can change if that devilish user keeps fiddling with things.
            if ([AAPLSwipeStateAnimatingOpen isEqualToString:self.currentState])
                self.currentState = AAPLSwipeStateEditing;
        }];
    }
    else
        [self shutActionPaneForEditingCellAnimated:YES];
}

#pragma mark - State Transition methods

- (void)didEnterEditingState
{
    _editingCell.userInteractionEnabled = YES;
    _editingCell.userInteractionEnabledForEditing = YES;
}

- (void)didExitEditingState
{
    _editingCell.userInteractionEnabledForEditing = NO;
}

- (void)didExitNothingState
{
    _collectionView.scrollEnabled = NO;
    [_editingCell showEditActions];
}

- (void)didEnterNothingState
{
    _collectionView.scrollEnabled = YES;
    _startTrackingX = 0;
    _editingCell.userInteractionEnabled = YES;
    [_editingCell hideEditActions];
    self.editingCell = nil;
}

- (void)didEnterAnimatingShutState
{
    _editingCell.userInteractionEnabled = NO;
    [_editingCell animateOutSwipeToEditAccessories];
}

- (void)didEnterAnimatingOpenState
{
    _editingCell.userInteractionEnabled = NO;
}

- (void)didExitAnimatingOpenState
{
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    SWIPE_LOG(@"batchEditing=%@ recogniser=%@ currentState=%@", NSStringFromBOOL(_batchEditing), (gestureRecognizer == _panGestureRecognizer ? @"Pan" : @"OTHER"), self.currentState);


    if (gestureRecognizer == _panGestureRecognizer) {
        // When batch editing, we transition to tracking when we detect a tap in the reorder control, so allow the pan recogniser to begin when we're tracking
        if (_batchEditing)
            return ([self.currentState isEqualToString:AAPLSwipeStateTracking]);

        if ([self.currentState isEqualToString:AAPLSwipeStateNothing] || [self.currentState isEqualToString:AAPLSwipeStateEditing] || [self.currentState isEqualToString:AAPLSwipeStateAnimatingOpen]) {
            // only if it's a AAPLCollectionViewCell
            NSIndexPath *panCellPath = [_collectionView indexPathForItemAtPoint:[_panGestureRecognizer locationInView:_collectionView]];
            CGPoint velocity = [_panGestureRecognizer velocityInView:_collectionView];
            AAPLCollectionViewCell *cell = (AAPLCollectionViewCell *)[_collectionView cellForItemAtIndexPath:panCellPath];

            if (![cell isKindOfClass:[AAPLCollectionViewCell class]])
                return NO;

            SWIPE_LOG(@"indexPath=%@ velocity=%@ cell=%@ editingCell=%@ numberOfActions=%lu", panCellPath, NSStringFromCGPoint(velocity), cell, _editingCell, (long)[cell.editActions count]);

            if (![self.currentState isEqualToString:AAPLSwipeStateNothing] && cell != _editingCell)
                return NO;

            if ([cell.editActions count] == 0)
                return NO;

            // only if there's enough x velocity
            if (fabs(velocity.y) >= fabs(velocity.x))
                return NO;

            _startTrackingX = cell.swipeTrackingPosition;
            self.editingCell = cell;
            self.currentState = AAPLSwipeStateTracking;
            return YES;
        }
        else
            return NO;
    }

    // It's some other gesture recogniser?
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return NO;
}

@end
