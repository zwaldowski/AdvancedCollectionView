/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of UICollectionViewController that adds support for swipe to edit and drag reordering.
  
 */

@interface AAPLCollectionViewController : UICollectionViewController <UICollectionViewDelegate>

@property (nonatomic, getter = isEditing) BOOL editing;

@end

@interface AAPLCollectionViewController (SwipeToDelete)
- (void)swipeToDeleteCell:(id)sender;
- (void)willDismissActionSheetFromCell:(UICollectionViewCell *)cell;
@end