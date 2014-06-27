/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The base collection view cell used by the AAPLCollectionViewGridLayout code. This cell provides swipe to edit and drag to reorder support.
  
*/

#import <UIKit/UIKit.h>

/// A subclass of UICollectionViewCell that enables editing and swipe to delete
@interface AAPLCollectionViewCell : UICollectionViewCell

@property (nonatomic, getter = isEditing) BOOL editing;

/// An array of AAPLAction instances that should be displayed when this cell has been swiped for editing.
@property (nonatomic, strong) NSArray *editActions;

/// Indicate that this cell should be refreshed in the collection view. This is typically used because the layout of the cell has changed and the collection view's layout should be invalidated.
- (void)invalidateCollectionViewLayout;

/// If you implement the setEditing: method, you MUST call super
- (void)setEditing:(BOOL)editing NS_REQUIRES_SUPER;

@end
