//
//  AAPLCollectionViewKeyboardSupport.h
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 6/18/15.
//  Copyright © 2015 Apple. All rights reserved.
//

@import UIKit;

@class UICollectionViewController;

@interface AAPLCollectionViewKeyboardSupport : NSObject

@property (nonatomic) BOOL viewIsDisappearing;
@property (nonatomic) BOOL registeredForNotifications;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCollectionViewController:(UICollectionViewController *)ctlr NS_DESIGNATED_INITIALIZER;

- (void)noteKeyboardWillShow:(NSNotification *)note;
- (void)noteKeyboardWillHide:(NSNotification *)note;
- (void)noteKeyboardDidChangeFrame:(NSNotification *)note;
- (void)noteKeyboardAnimationCompleted:(NSNotification *)note; // did show, did hide

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator;

@end
