/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A state machine that manages a UILongPressGestureRecognizer and a UIPanGestureRecognizer to handle swipe to edit as well as drag to reorder.
 */

@import UIKit;

NS_ASSUME_NONNULL_BEGIN




@class UICollectionView;

/// A state machine that manages a UILongPressGestureRecognizer and a UIPanGestureRecognizer to handle swipe to edit as well as drag to reorder.
@interface AAPLSwipeToEditController : NSObject

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView NS_DESIGNATED_INITIALIZER;

- (void)viewDidDisappear:(BOOL)animated;
- (void)shutActionPaneForEditingCellAnimated:(BOOL)animate;

@property (nullable, nonatomic, readonly) NSIndexPath *trackedIndexPath;
@property (nonatomic, getter = isEditing) BOOL editing;
@property (nonatomic, readonly, getter = isIdle) BOOL idle;


- (instancetype)init NS_UNAVAILABLE;

@end




NS_ASSUME_NONNULL_END
