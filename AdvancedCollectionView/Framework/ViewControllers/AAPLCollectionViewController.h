/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of UICollectionViewController that adds support for swipe to edit and drag reordering.
 */

NS_ASSUME_NONNULL_BEGIN




@class AAPLAction;

/// A subclass of UICollectionViewController that adds support for swipe to edit and drag reordering.
@interface AAPLCollectionViewController : UICollectionViewController <UICollectionViewDelegate>

@property (nonatomic, getter = isEditing) BOOL editing;

/// Amount to inset content in this view controller. By default, this value will be calculated based on whether the view for this view controller intersects the status bar, navigation bar, and tab bar. The contentInsets are also updated if the keyboard is displayed and its frame intersects with the frame of this controller's view.
@property (nonatomic) UIEdgeInsets contentInsets;

@end

@interface AAPLCollectionViewController (AAPLCollectionViewControllerEditingActions)
- (void)swipeToDeleteCell:(__kindof UICollectionViewCell *)cell;
- (void)didSelectActionFromCell:(__kindof UICollectionViewCell *)cell;
- (void)presentAlertSheetFromCell:(__kindof UICollectionViewCell *)cell;
@end




NS_ASSUME_NONNULL_END
