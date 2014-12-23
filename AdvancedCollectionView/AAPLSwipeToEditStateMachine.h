/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A state machine that manages a UIPanGestureRecognizer to handle swipe to edit.
  
 */

#import "AAPLStateMachine.h"
@import UIKit;

extern NSString * const AAPLSwipeStateNothing;
extern NSString * const AAPLSwipeStateEditing;
extern NSString * const AAPLSwipeStateTracking;
extern NSString * const AAPLSwipeStateAnimatingOpen;
extern NSString * const AAPLSwipeStateAnimatingShut;

@interface AAPLSwipeToEditStateMachine : AAPLStateMachine <UIGestureRecognizerDelegate>

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView;

- (void)viewDidDisappear:(BOOL)animated;
- (void)shutActionPaneForEditingCellAnimated:(BOOL)animate;

@property (nonatomic, readonly) NSIndexPath *trackedIndexPath;
@property (nonatomic, getter = isBatchEditing) BOOL batchEditing;

@end
