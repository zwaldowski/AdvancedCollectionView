/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The base collection view cell used by the AAPLCollectionViewGridLayout code. This cell provides swipe to edit and drag to reorder support.
  
  This file contains properties and methods that are used for communication internally between the layout, the swipe to edit state machine and other mechanisms. Most likely, it is not necessary to access these methods and properties to use AAPLCollectionViewCell correctly.
  
 */

#import "AAPLCollectionViewCell.h"

@interface AAPLCollectionViewCell ()

@property (nonatomic) BOOL userInteractionEnabledForEditing;

@property (nonatomic, readonly, strong) UIView *actionsView;
@property (nonatomic, readonly, strong) UIView *removeControl;
@property (nonatomic, readonly, strong) UIView *reorderControl;

@property (nonatomic) CGFloat swipeTrackingPosition;
@property (nonatomic, readonly) CGFloat minimumSwipeTrackingPosition;

/// If your collection view doesn't have separators between cells, you can set this to YES to display separators while editing. Default is NO.
@property (nonatomic) BOOL showsSeparatorsWhileEditing;

/// The color of the separators that will be shown while editing. Ignored if showsSeparatorsWhileEditing is NO.
@property (nonatomic, strong) UIColor *separatorColor;

/// Will a reorder control be shown while this cell is in edit mode? Default is NO.
@property (nonatomic) BOOL showsReorderControl;

// this is called during a UIView animation block for when the cell is removed
- (void)closeForDelete;

- (void)closeActionPaneAnimated:(BOOL)animate completionHandler:(void(^)(BOOL finished))handler;
- (void)openActionPaneAnimated:(BOOL)animated completionHandler:(void(^)(BOOL finished))handler;

// required calls
- (void)showEditActions;
- (void)hideEditActions;

// starts fading out the top and bottom hairline views -- they'll normally fade out at finishEditing
- (void)animateOutSwipeToEditAccessories;

@end
