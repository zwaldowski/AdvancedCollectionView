/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The base collection view cell used by the AAPLCollectionViewLayout code. This cell provides swipe to edit and drag to reorder support.
 
  This file contains properties and methods that are used for communication internally between the layout, the swipe to edit state machine and other mechanisms. Most likely, it is not necessary to access these methods and properties to use AAPLCollectionViewCell correctly.
 */

#import "AAPLCollectionViewCell.h"

@class AAPLAction;

typedef NS_ENUM(NSInteger, AAPLCollectionViewCellSwipeType) {
    AAPLCollectionViewCellSwipeTypeNone = 0,
    /// A swipe from the right edge towards the left edge exposing the primary actions.
    AAPLCollectionViewCellSwipeTypePrimary,
    /// A swipe from the left edge towards the right edge exposing the secondary actions.
    AAPLCollectionViewCellSwipeTypeSecondary
};

@interface AAPLCollectionViewCell ()

/// The rectangle of the remove control within the cell.
@property (nonatomic, readonly) CGRect removeControlRect;
/// The rectangle of the reorder control within the cell.
@property (nonatomic, readonly) CGRect reorderControlRect;
/// The rectangle of the actions view within the cell.
@property (nonatomic, readonly) CGRect actionsViewRect;

/// Begin or continue a swipe operation.
- (void)beginSwipeWithPosition:(CGPoint)position velocity:(CGFloat)velocity;

/// Update the swipe tracking information with the current position and velocity.
- (void)updateSwipeWithPosition:(CGPoint)position velocity:(CGFloat)velocity;

/// End the swipe and return whether the position and velocity is sufficient to keep the action view open
- (BOOL)endSwipeWithPosition:(CGPoint)position;

/// An array of AAPLAction instances that should be displayed when this cell has been swiped for editing.
@property (nonatomic, copy) NSArray<AAPLAction *> *editActions;

/// The type of swipe, Primary or Secondary.
@property (nonatomic) AAPLCollectionViewCellSwipeType swipeType;

/// If your collection view doesn't have separators between cells, you can set this to YES to display separators while editing. Default is NO.
@property (nonatomic) BOOL showsSeparatorsWhileEditing;

/// The color of the separators that will be shown while editing. Ignored if showsSeparatorsWhileEditing is NO.
@property (nonatomic, strong) UIColor *separatorColor;

/// Will a reorder control be shown while this cell is in edit mode? Default is NO.
@property (nonatomic) BOOL showsReorderControl;

- (void)closeActionPaneAnimated:(BOOL)animate completionHandler:(void(^)(BOOL finished))handler;
- (void)openActionPaneAnimated:(BOOL)animated completionHandler:(void(^)(BOOL finished))handler;

/// Prepares the cell for deletion due to user interaction
- (void)prepareForInteractiveRemoval;

@end
