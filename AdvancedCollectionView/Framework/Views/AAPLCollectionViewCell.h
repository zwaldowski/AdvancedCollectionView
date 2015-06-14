/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The base collection view cell used by the AAPLCollectionViewLayout code. This cell provides swipe to edit and drag to reorder support.
 */

@import UIKit;

NS_ASSUME_NONNULL_BEGIN




@class AAPLTheme;

/// A subclass of `UICollectionViewCell` that enables editing and swipe to delete
@interface AAPLCollectionViewCell : UICollectionViewCell

/// Is the cell in editing mode?
@property (nonatomic, getter = isEditing) BOOL editing;

/// The theme this cell should use to resolve any unknown values
@property (nonatomic, strong) AAPLTheme *theme;

/// If you implement the setEditing: method, you MUST call super
- (void)setEditing:(BOOL)editing NS_REQUIRES_SUPER;

/// Inform the containing collection view that we need this cell to be redrawn.
- (void)invalidateCollectionViewLayout;

@end


/// A helpful macro to allow using the view class name as the reusable identifier.
#define AAPLReusableIdentifierFromClass(viewClass) NSStringFromClass([viewClass class])




NS_ASSUME_NONNULL_END
