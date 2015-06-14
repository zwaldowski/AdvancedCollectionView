/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
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

#import "AAPLSwipeToEditController.h"
#import "AAPLCollectionViewCell_Private.h"
#import "AAPLCollectionViewLayout_Private.h"
#import "AAPLDataSource.h"
#import "AAPLStateMachine.h"
#import <libkern/OSAtomic.h>
#import <objc/message.h>

@interface AAPLGestureRecognizerWrapper : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIGestureRecognizer *gestureRecognizer;
@property (nonatomic, weak) id<UIGestureRecognizerDelegate> target;
@property (nonatomic) SEL action;
@property (nonatomic) SEL shouldBegin;

+ (instancetype)wrapperWithGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer target:(id<UIGestureRecognizerDelegate>)target;

@end;

@implementation AAPLGestureRecognizerWrapper

+ (instancetype)wrapperWithGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer target:(id<UIGestureRecognizerDelegate>)target
{
    return [[self alloc] initWithGestureRecognizer:gestureRecognizer target:target action:NULL shouldBegin:NULL];
}

- (instancetype)initWithGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer target:(id<UIGestureRecognizerDelegate>)target action:(SEL)action shouldBegin:(SEL)shouldBegin
{
    NSParameterAssert(gestureRecognizer != nil);
    NSParameterAssert(target != nil);

    self = [super init];
    if (!self)
        return nil;

    _gestureRecognizer = gestureRecognizer;
    _target = target;
    _action = action;
    _shouldBegin = shouldBegin;

    gestureRecognizer.delegate = self;
    [gestureRecognizer addTarget:self action:@selector(handleAction:)];

    return self;
}

- (void)dealloc
{
    _gestureRecognizer.delegate = nil;
}

- (void)handleAction:(UIGestureRecognizer *)gestureRecognizer
{
    SEL action = self.action;
    if (!action)
        return;

    typedef BOOL (*ObjCMsgSendReturnBoolWithId)(id, SEL, id);
    ObjCMsgSendReturnBoolWithId doAction = (ObjCMsgSendReturnBoolWithId)objc_msgSend;

    doAction(self.target, action, gestureRecognizer);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return [self.target gestureRecognizer:gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (!self.shouldBegin)
        return NO;

    typedef BOOL (*ObjCMsgSendReturnBoolWithId)(id, SEL, id);
    ObjCMsgSendReturnBoolWithId shouldBegin = (ObjCMsgSendReturnBoolWithId)objc_msgSend;

    return shouldBegin(self.target, self.shouldBegin, gestureRecognizer);
}

@end


NSString * const AAPLSwipeStateIdle = @"IdleState";
NSString * const AAPLSwipeStateEditing = @"EditingState";
NSString * const AAPLSwipeStateTracking = @"TrackingState";
NSString * const AAPLSwipeStateMoving = @"MovingState";
NSString * const AAPLSwipeStateOpen = @"OpenState";
NSString * const AAPLSwipeStateEditOpen = @"EditOpenState";



@interface AAPLSwipeToEditController () <AAPLStateMachineDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, readonly) AAPLDataSource *dataSource;
@property (nonatomic, strong) AAPLCollectionViewCell *editingCell;
@property (nonatomic, strong) AAPLGestureRecognizerWrapper *longPressWrapper;
@property (nonatomic, strong) AAPLGestureRecognizerWrapper *panWrapper;
@property (nonatomic, strong) AAPLStateMachine *stateMachine;
@property (nonatomic, copy) NSString *currentState;
@end

@implementation AAPLSwipeToEditController

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView
{
    self = [super init];
    if (!self)
        return nil;

    _collectionView = collectionView;

    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:NULL];

    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:nil action:NULL];
    longPressGestureRecognizer.minimumPressDuration = 0.05;

    _longPressWrapper = [AAPLGestureRecognizerWrapper wrapperWithGestureRecognizer:longPressGestureRecognizer target:self];
    _panWrapper = [AAPLGestureRecognizerWrapper wrapperWithGestureRecognizer:panGestureRecognizer target:self];

    for (UIGestureRecognizer *recognizer in _collectionView.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]])
            [recognizer requireGestureRecognizerToFail:panGestureRecognizer];
        if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]])
            [recognizer requireGestureRecognizerToFail:longPressGestureRecognizer];
    }

    [collectionView addGestureRecognizer:panGestureRecognizer];
    [collectionView addGestureRecognizer:longPressGestureRecognizer];

    _stateMachine = [[AAPLStateMachine alloc] init];
    _stateMachine.delegate = self;
    _stateMachine.validTransitions = @{
                                       AAPLSwipeStateIdle : @[AAPLSwipeStateTracking, AAPLSwipeStateEditing],
                                       AAPLSwipeStateEditing : @[AAPLSwipeStateIdle, AAPLSwipeStateEditOpen, AAPLSwipeStateMoving],
                                       AAPLSwipeStateTracking : @[AAPLSwipeStateIdle, AAPLSwipeStateOpen],
                                       AAPLSwipeStateOpen : @[AAPLSwipeStateTracking, AAPLSwipeStateIdle],
                                       AAPLSwipeStateMoving : @[AAPLSwipeStateEditing],
                                       AAPLSwipeStateEditOpen : @[AAPLSwipeStateEditing]
                                       };
    _stateMachine.currentState = AAPLSwipeStateIdle;

    return self;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Don't call %@.", @(__PRETTY_FUNCTION__)];
    return nil;
}

- (AAPLDataSource *)dataSource
{
    AAPLDataSource *dataSource = (AAPLDataSource *)self.collectionView.dataSource;
    if ([dataSource isKindOfClass:[AAPLDataSource class]])
        return dataSource;
    else
        return nil;
}

- (NSString *)currentState
{
    return _stateMachine.currentState;
}

- (void)setCurrentState:(NSString *)currentState
{
    SWIPE_LOG(@"%@", currentState);
    _stateMachine.currentState = currentState;
}

- (BOOL)isIdle
{
    return [_stateMachine.currentState isEqualToString:AAPLSwipeStateIdle];
}

- (BOOL)isEditing
{
    NSString *currentState = self.currentState;
    return ([currentState isEqualToString:AAPLSwipeStateEditing] || [currentState isEqualToString:AAPLSwipeStateEditOpen] || [currentState isEqualToString:AAPLSwipeStateMoving]);
}

- (void)setEditing:(BOOL)editing
{
    NSString *currentState = self.currentState;

    if ([currentState isEqualToString:AAPLSwipeStateOpen] || [currentState isEqualToString:AAPLSwipeStateTracking])
        self.currentState = AAPLSwipeStateIdle;
    else if ([currentState isEqualToString:AAPLSwipeStateEditOpen] || [currentState isEqualToString:AAPLSwipeStateMoving])
        self.currentState = AAPLSwipeStateEditing;

    self.currentState = editing ? AAPLSwipeStateEditing : AAPLSwipeStateIdle;
}

- (NSIndexPath *)trackedIndexPath
{
    return [_collectionView indexPathForCell:_editingCell];
}

- (void)setDelegate:(id<AAPLStateMachineDelegate>)delegate
{
    NSAssert(NO, @"you're not the boss of me");
}

- (void)setEditingCell:(AAPLCollectionViewCell *)editingCell
{
    if (_editingCell == editingCell)
        return;
    _editingCell = editingCell;
}

- (void)shutActionPaneForEditingCellAnimated:(BOOL)animate
{
    // This basically backs out of the Open or EditOpen states
    NSString *currentState = self.currentState;

    void (^shut)() = ^{
        if ([currentState isEqualToString:AAPLSwipeStateEditOpen])
            self.currentState = AAPLSwipeStateEditing;
        else if ([currentState isEqualToString:AAPLSwipeStateOpen])
            self.currentState = AAPLSwipeStateIdle;
    };

    if (!animate)
        [UIView performWithoutAnimation:shut];
    else
        shut();
}

- (void)viewDidDisappear:(BOOL)animated
{
    NSString *currentState = self.currentState;

    // Need to transition to editing before going to idle
    if ([currentState isEqualToString:AAPLSwipeStateEditOpen] || [currentState isEqualToString:AAPLSwipeStateMoving])
        self.currentState = AAPLSwipeStateEditing;

    if (![currentState isEqualToString:AAPLSwipeStateIdle])
        self.currentState = AAPLSwipeStateIdle;
}

#pragma mark - Gesture Recognizer action methods

- (void)handleMovingPan:(UIPanGestureRecognizer *)recognizer
{
    UICollectionView *collectionView = self.collectionView;
    AAPLCollectionViewLayout *layout = (AAPLCollectionViewLayout *)collectionView.collectionViewLayout;
    if ([layout isKindOfClass:[AAPLCollectionViewLayout class]])
        [layout handlePanGesture:recognizer];
}

- (void)handleSwipePan:(UIPanGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            CGPoint position = [recognizer locationInView:_editingCell];
            CGFloat velocityX = [recognizer velocityInView:_editingCell].x;
            [_editingCell beginSwipeWithPosition:position velocity:velocityX];
            break;
        }
        case UIGestureRecognizerStateChanged:
        {
            CGPoint position = [recognizer locationInView:_editingCell];
            CGFloat velocityX = [recognizer velocityInView:_editingCell].x;
            [_editingCell updateSwipeWithPosition:position velocity:velocityX];
            self.currentState = AAPLSwipeStateTracking;
            break;
        }
        case UIGestureRecognizerStateEnded:
        {
            CGPoint position = [recognizer locationInView:_editingCell];

            if ([self.editingCell endSwipeWithPosition:position])
                self.currentState = AAPLSwipeStateOpen;
            else
                self.currentState = AAPLSwipeStateIdle;
            break;
        }
        case UIGestureRecognizerStateCancelled:
        {
            self.currentState = AAPLSwipeStateIdle;
            break;
        }
        default:
            break;
    }
}

- (void)handleMovingLongPress:(UILongPressGestureRecognizer *)recognizer
{
    UICollectionView *collectionView = self.collectionView;
    AAPLCollectionViewLayout *layout = (AAPLCollectionViewLayout *)collectionView.collectionViewLayout;
    if (![layout isKindOfClass:[AAPLCollectionViewLayout class]])
        layout = nil;

    NSIndexPath *indexPath = self.trackedIndexPath;

    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            [layout beginDraggingItemAtIndexPath:indexPath];
            break;

        case UIGestureRecognizerStateCancelled:
            [layout cancelDragging];
            self.currentState = AAPLSwipeStateEditing;
            break;

        case UIGestureRecognizerStateEnded:
            [layout endDragging];
            self.currentState = AAPLSwipeStateEditing;
            break;

        default:
            break;
    }
}

- (void)handleOpenLongPress:(UILongPressGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint cellLocation = [recognizer locationInView:self.editingCell];
            if (CGRectContainsPoint(self.editingCell.bounds, cellLocation))
                break;

            self.currentState = AAPLSwipeStateIdle;
            // Cancel the recognizer by disabling & re-enabling it. This prevents it from firing an end state notification.
            recognizer.enabled = NO;
            recognizer.enabled = YES;
            break;
        }

        case UIGestureRecognizerStateCancelled:
            self.currentState = AAPLSwipeStateIdle;
            break;

        case UIGestureRecognizerStateEnded:
            self.currentState = AAPLSwipeStateIdle;
            break;

        default:
            break;
    }
}

- (void)handleEditOpenLongPress:(UILongPressGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint cellLocation = [recognizer locationInView:self.editingCell];
            if (CGRectContainsPoint(self.editingCell.bounds, cellLocation))
                break;

            self.currentState = AAPLSwipeStateEditing;
            // Cancel the recognizer by disabling & re-enabling it. This prevents it from firing an end state notification.
            recognizer.enabled = NO;
            recognizer.enabled = YES;
            break;
        }

        case UIGestureRecognizerStateCancelled:
            self.currentState = AAPLSwipeStateEditing;
            break;

        case UIGestureRecognizerStateEnded:
            self.currentState = AAPLSwipeStateEditing;
            break;

        default:
            break;
    }
}

- (void)handleEditingLongPress:(UILongPressGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            break;

        case UIGestureRecognizerStateCancelled:
            break;

        case UIGestureRecognizerStateEnded:
        {
            // Tap in the remove control. If the data source doesn't define any actions for this index path, then there's really nothing to do.
            NSArray *actions = [self.dataSource primaryActionsForItemAtIndexPath:self.trackedIndexPath];
            if (!actions.count)
                return;

            // Tell the cell about the actions
            _editingCell.editActions = actions;
            self.currentState = AAPLSwipeStateEditOpen;
            break;
        }

        default:
            break;
    }
}

#pragma mark - State Transition methods

- (void)didExitTrackingState
{
    self.panWrapper.shouldBegin = NULL;
    self.panWrapper.action = NULL;
}

- (void)didEnterTrackingState
{
    // Toggle the long press gesture recogniser to ensure we don't get an accidental trigger if tracking doesn't last long enough.
    self.longPressWrapper.gestureRecognizer.enabled = NO;
    self.longPressWrapper.gestureRecognizer.enabled = YES;


    self.panWrapper.action = @selector(handleSwipePan:);
}

- (void)didExitOpenState
{
    self.longPressWrapper.action = NULL;
    self.longPressWrapper.shouldBegin = NULL;

    self.panWrapper.shouldBegin = NULL;
    self.panWrapper.action = NULL;
}

- (void)didEnterOpenState
{
    self.longPressWrapper.action = @selector(handleOpenLongPress:);
    self.longPressWrapper.shouldBegin = @selector(longPressGestureRecognizerShouldBeginWhileOpen:);

    self.panWrapper.shouldBegin = @selector(panGestureRecognizerShouldBeginWhileOpen:);
    self.panWrapper.action = @selector(handleSwipePan:);

    _collectionView.scrollEnabled = NO;

    [self.editingCell openActionPaneAnimated:YES completionHandler:nil];
}

- (void)didExitEditOpenState
{
    self.longPressWrapper.action = NULL;
    self.longPressWrapper.shouldBegin = NULL;
}

- (void)didEnterEditOpenState
{
    self.longPressWrapper.action = @selector(handleEditOpenLongPress:);
    self.longPressWrapper.shouldBegin = @selector(longPressGestureRecognizerShouldBeginWhileOpen:);

    _collectionView.scrollEnabled = NO;

    [self.editingCell openActionPaneAnimated:YES completionHandler:nil];
}

- (void)didExitEditingState
{
    self.longPressWrapper.action = NULL;
    self.longPressWrapper.shouldBegin = NULL;
}

- (void)didEnterEditingState
{
    self.longPressWrapper.action = @selector(handleEditingLongPress:);
    self.longPressWrapper.shouldBegin = @selector(longPressGestureRecognizerShouldBeginWhileEditing:);

    _collectionView.scrollEnabled = YES;

    [self.editingCell closeActionPaneAnimated:YES completionHandler:^(BOOL finished) {
        self.editingCell = nil;
    }];
}

- (void)didExitIdleState
{
    self.panWrapper.shouldBegin = NULL;
    self.panWrapper.action = NULL;
}

- (void)didEnterIdleState
{
    self.panWrapper.shouldBegin = @selector(panGestureRecognizerShouldBeginWhileIdle:);
    self.panWrapper.action = @selector(handleSwipePan:);

    _collectionView.scrollEnabled = YES;

    AAPLCollectionViewCell *cell = self.editingCell;
    self.editingCell = nil;

    [cell closeActionPaneAnimated:YES completionHandler:nil];
}

- (void)didExitMovingState
{
    self.panWrapper.action = NULL;
    self.panWrapper.shouldBegin = NULL;

    self.longPressWrapper.action = NULL;
    self.longPressWrapper.shouldBegin = NULL;
}

- (void)didEnterMovingState
{
    self.panWrapper.action = @selector(handleMovingPan:);
    self.panWrapper.shouldBegin = @selector(panGestureRecognizerShouldBeginWhileMoving:);
    self.longPressWrapper.action = @selector(handleMovingLongPress:);
    self.longPressWrapper.shouldBegin = NULL;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)longPressGestureRecognizerShouldBeginWhileEditing:(UIGestureRecognizer *)gestureRecognizer
{
    NSUInteger numberOfTouches = gestureRecognizer.numberOfTouches;
    for (NSUInteger touchIndex = 0; touchIndex < numberOfTouches; ++touchIndex) {
        CGPoint touchLocation = [gestureRecognizer locationOfTouch:touchIndex inView:_collectionView];
        NSIndexPath *indexPath = [_collectionView indexPathForItemAtPoint:touchLocation];
        AAPLCollectionViewCell *cell = (AAPLCollectionViewCell *)[_collectionView cellForItemAtIndexPath:indexPath];
        if (![cell isKindOfClass:[AAPLCollectionViewCell class]])
            return NO;

        CGPoint cellLocation = [gestureRecognizer locationOfTouch:touchIndex inView:cell];

        // Check if the tap is in the remove control
        if (CGRectContainsPoint(cell.removeControlRect, cellLocation)) {
            _editingCell = cell;
            return YES;
        }

        // Check if the tap is in the reorder control
        if (CGRectContainsPoint(cell.reorderControlRect, cellLocation)) {
            _editingCell = cell;
            self.currentState = AAPLSwipeStateMoving;
            return YES;
        }
    }

    _editingCell = nil;

    // Didn't find a touch in the remove control
    return NO;
}

- (BOOL)longPressGestureRecognizerShouldBeginWhileOpen:(UIGestureRecognizer *)gestureRecognizer
{
    // don't allow the cancel gesture to recognise if any of the touches are within the edit actions
    NSUInteger numberOfTouches = gestureRecognizer.numberOfTouches;
    CGRect actionsViewRect = _editingCell.actionsViewRect;

    for (NSUInteger touchIndex = 0; touchIndex < numberOfTouches; ++touchIndex) {
        CGPoint touchLocation = [gestureRecognizer locationOfTouch:touchIndex inView:_editingCell];
        if (CGRectContainsPoint(actionsViewRect, touchLocation))
            return NO;
    }

    return YES;
}

- (BOOL)panGestureRecognizerShouldBeginWhileMoving:(UIGestureRecognizer *)gestureRecognizer
{
    return YES;
}


- (BOOL)panGestureRecognizerShouldBeginWhileOpen:(UIGestureRecognizer *)gestureRecognizer
{
    // only if it's a AAPLCollectionViewCell
    CGPoint position = [gestureRecognizer locationInView:_collectionView];
    NSIndexPath *panCellPath = [_collectionView indexPathForItemAtPoint:position];
    AAPLCollectionViewCell *cell = (AAPLCollectionViewCell *)[_collectionView cellForItemAtIndexPath:panCellPath];

    if (![cell isKindOfClass:[AAPLCollectionViewCell class]])
        return NO;

    return (cell == _editingCell);
}

- (BOOL)panGestureRecognizerShouldBeginWhileIdle:(UIGestureRecognizer *)gestureRecognizer
{
    UIPanGestureRecognizer *panGestureRecognizer = (UIPanGestureRecognizer *)gestureRecognizer;

    // only if it's a AAPLCollectionViewCell
    CGPoint position = [panGestureRecognizer locationInView:_collectionView];
    NSIndexPath *panCellPath = [_collectionView indexPathForItemAtPoint:position];
    CGPoint velocity = [panGestureRecognizer velocityInView:_collectionView];
    AAPLCollectionViewCell *cell = (AAPLCollectionViewCell *)[_collectionView cellForItemAtIndexPath:panCellPath];

    SWIPE_LOG(@"cell=%@", cell);

    if (![cell isKindOfClass:[AAPLCollectionViewCell class]])
        return NO;

    SWIPE_LOG(@"indexPath=%@ velocity=%@ cell=%@ editingCell=%@", panCellPath, NSStringFromCGPoint(velocity), cell, _editingCell);

    // only if there's enough x velocity
    if (fabs(velocity.y) >= fabs(velocity.x))
        return NO;

    NSArray *editActions;

    if (velocity.x < 0)
        editActions = [self.dataSource primaryActionsForItemAtIndexPath:panCellPath];
    else
        editActions = [self.dataSource secondaryActionsForItemAtIndexPath:panCellPath];

    SWIPE_LOG(@"edit actions = %@", editActions);

    if (!editActions.count)
        return NO;

    cell.editActions = editActions;
    cell.swipeType = (velocity.x < 0 ? AAPLCollectionViewCellSwipeTypePrimary : AAPLCollectionViewCellSwipeTypeSecondary);

    self.editingCell = cell;
    self.currentState = AAPLSwipeStateTracking;
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    SWIPE_LOG(@"gestureRecognizer:%@ otherRecognizer:%@", gestureRecognizer, otherGestureRecognizer);
    
    if ([_longPressWrapper.gestureRecognizer isEqual:gestureRecognizer])
        return [_panWrapper.gestureRecognizer isEqual:otherGestureRecognizer];
    
    if ([_panWrapper.gestureRecognizer isEqual:gestureRecognizer])
        return [_longPressWrapper.gestureRecognizer isEqual:otherGestureRecognizer];
    
    return NO;
}

@end
