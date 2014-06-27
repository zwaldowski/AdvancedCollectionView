/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A state machine that manages a UILongPressGestureRecognizer and a UIPanGestureRecognizer to handle swipe to edit as well as drag to reorder.
  
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
#import <libkern/OSAtomic.h>

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
#define REORDER_CONTROL_EDGE_INSETS UIEdgeInsetsMake(-15, -15, -15, -15)

@interface AAPLCancelSwipeToEditGestureRecognizer : UITapGestureRecognizer

@property (nonatomic, retain) AAPLCollectionViewCell *currentEditingCell; // rect where this gesture recognizer does not work within the owning view coordinate space

@end

@interface AAPLSwipeToEditStateMachine ()
{
    aapl_debounce_t _debounce;
}

@property (nonatomic, strong) UICollectionView *collectionView;

@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong) AAPLCollectionViewCell *editingCell;
@property (nonatomic) CGFloat startTrackingX;

@end

@implementation AAPLSwipeToEditStateMachine

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView;
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

    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    _longPressGestureRecognizer.minimumPressDuration = 0.05;
    _longPressGestureRecognizer.delegate = self;

    for (UIGestureRecognizer *recognizer in _collectionView.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]])
            [recognizer requireGestureRecognizerToFail:_panGestureRecognizer];
        if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]])
            [recognizer requireGestureRecognizerToFail:_longPressGestureRecognizer];
    }

    [collectionView addGestureRecognizer:_panGestureRecognizer];
    [collectionView addGestureRecognizer:_longPressGestureRecognizer];

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
    return MIN(0, _startTrackingX + translation.x);
}

- (void)shutActionPaneForEditingCellAnimated:(BOOL)animate
{
    // our cancel gesture recognizer comes through this code path, and should normally cause the edit pane to slide shut except for when some control on screen, like a segmented control, triggers the pane to slide shut without animation. in that case, we need to preempt any animation with a debounce.
    if (animate) {
        // the segmented datasource might have changed in the same event loop, so delay this one loop cycle later
        dispatch_async(dispatch_get_main_queue(), ^{
            aapl_debounce(&_debounce, ^{
                // somebody might have already shut us by the time we're called, so only shut if we're not already
                if (![self.currentState isEqualToString:AAPLSwipeStateNothing]) {
                    self.currentState = AAPLSwipeStateAnimatingShut;
                    [_editingCell closeActionPaneAnimated:YES completionHandler:^(BOOL finished) {
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
            [_editingCell closeActionPaneAnimated:NO completionHandler:nil];
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
    if (!_batchEditing)
        [self handleNormalPan:recognizer];
    else
        [self handleBatchEditPan:recognizer];
}

- (void)handleBatchEditPan:(UIPanGestureRecognizer *)recognizer
{
    UICollectionView *collectionView = self.collectionView;
    AAPLCollectionViewGridLayout *layout = (AAPLCollectionViewGridLayout *)collectionView.collectionViewLayout;
    if ([layout isKindOfClass:[AAPLCollectionViewGridLayout class]])
        [layout handlePanGesture:recognizer];
}

- (void)handleNormalPan:(UIPanGestureRecognizer *)recognizer
{
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
                CGFloat velocityX = (0.2*[recognizer velocityInView:_editingCell].x);

                CGFloat finalX = translatedPoint.x + velocityX;

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

                finalX = MAX(targetX, finalX);
                CGFloat animationDuration = (ABS(velocityX)*.0002)+.2;

                self.currentState = AAPLSwipeStateAnimatingOpen;
                [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    _editingCell.swipeTrackingPosition = finalX;
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

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
    UICollectionView *collectionView = self.collectionView;
    AAPLCollectionViewGridLayout *layout = (AAPLCollectionViewGridLayout *)collectionView.collectionViewLayout;
    if (![layout isKindOfClass:[AAPLCollectionViewGridLayout class]])
        layout = nil;

    NSIndexPath *indexPath = self.trackedIndexPath;

    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            if (_batchEditing && [self.currentState isEqualToString:AAPLSwipeStateTracking])
                [layout beginDraggingItemAtIndexPath:indexPath];
            break;

        case UIGestureRecognizerStateCancelled:
            if (_batchEditing && [self.currentState isEqualToString:AAPLSwipeStateTracking])
                [layout cancelDragging];
            self.currentState = AAPLSwipeStateNothing;
            break;
            
        case UIGestureRecognizerStateEnded:
            if ([self.currentState isEqualToString:AAPLSwipeStateEditing] || [self.currentState isEqualToString:AAPLSwipeStateAnimatingOpen])
                [self shutActionPaneForEditingCellAnimated:YES];
            else if (_batchEditing && [self.currentState isEqualToString:AAPLSwipeStateTracking]) {
                [layout endDragging];
                self.currentState = AAPLSwipeStateNothing;
            }
            else if ([self.currentState isEqualToString:AAPLSwipeStateNothing]) {
                // Tap in the remove control
                self.currentState = AAPLSwipeStateAnimatingOpen;
                [_editingCell openActionPaneAnimated:YES completionHandler:^(BOOL finished){
                    // Only set it to editing if we're still in the same state as we previously set. It can change if that devilish user keeps fiddling with things.
                    if ([AAPLSwipeStateAnimatingOpen isEqualToString:self.currentState])
                        self.currentState = AAPLSwipeStateEditing;
                }];
            }
            break;

        default:
            break;
    }
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
    SWIPE_LOG(@"batchEditing=%@ recogniser=%@ currentState=%@", NSStringFromBOOL(_batchEditing), (gestureRecognizer==_longPressGestureRecognizer ? @"LongPress" : (gestureRecognizer == _panGestureRecognizer ? @"Pan" : @"OTHER")), self.currentState);

    if (gestureRecognizer == _longPressGestureRecognizer) {
        // handle batch editing taps in the remove and reorder controls
        if (_batchEditing && [self.currentState isEqualToString:AAPLSwipeStateNothing]) {

            NSUInteger numberOfTouches = gestureRecognizer.numberOfTouches;
            for (NSUInteger touchIndex = 0; touchIndex < numberOfTouches; ++touchIndex) {
                CGPoint touchLocation = [gestureRecognizer locationOfTouch:touchIndex inView:_collectionView];
                NSIndexPath *indexPath = [_collectionView indexPathForItemAtPoint:touchLocation];
                AAPLCollectionViewCell *cell = (AAPLCollectionViewCell *)[_collectionView cellForItemAtIndexPath:indexPath];
                if (![cell isKindOfClass:[AAPLCollectionViewCell class]])
                    return NO;

                // Check if the tap is in the remove control
                UIView *removeControl = cell.removeControl;
                CGRect removeBounds = UIEdgeInsetsInsetRect(removeControl.bounds, REMOVE_CONTROL_EDGE_INSETS);
                touchLocation = [gestureRecognizer locationOfTouch:touchIndex inView:removeControl];
                if (CGRectContainsPoint(removeBounds, touchLocation)) {
                    _editingCell = cell;
                    return YES;
                }

                // Check if the tap is in the reorder control
                UIView *reorderControl = cell.reorderControl;
                CGRect reorderBounds = UIEdgeInsetsInsetRect(reorderControl.bounds, REORDER_CONTROL_EDGE_INSETS);
                touchLocation = [gestureRecognizer locationOfTouch:touchIndex inView:reorderControl];
                if (CGRectContainsPoint(reorderBounds, touchLocation)) {
                    _editingCell = cell;
                    self.currentState = AAPLSwipeStateTracking;
                    return YES;
                }
            }

            _editingCell = nil;
            // Didn't find a touch that was in the remove control
            return NO;
        }

        // cancel taps only work once we're in full edit mode or animating open
        if (![self.currentState isEqualToString:AAPLSwipeStateEditing] && ![self.currentState isEqualToString:AAPLSwipeStateAnimatingOpen])
            return NO;

        // don't allow the cancel gesture to recognise if any of the touches are within the edit actions
        NSUInteger numberOfTouches = gestureRecognizer.numberOfTouches;
        UIView *editActionsView = _editingCell.actionsView;
        CGRect disabledRect = editActionsView.bounds;

        for (NSUInteger touchIndex = 0; touchIndex < numberOfTouches; ++touchIndex) {
            CGPoint touchLocation = [gestureRecognizer locationOfTouch:touchIndex inView:editActionsView];
            if (CGRectContainsPoint(disabledRect, touchLocation))
                return NO;
        }
        
        return YES;
    }

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
            if (abs(velocity.y) >= abs(velocity.x))
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
    if ([_longPressGestureRecognizer isEqual:gestureRecognizer])
        return [_panGestureRecognizer isEqual:otherGestureRecognizer];

    if ([_panGestureRecognizer isEqual:gestureRecognizer])
        return [_longPressGestureRecognizer isEqual:otherGestureRecognizer];

    return NO;
}

@end