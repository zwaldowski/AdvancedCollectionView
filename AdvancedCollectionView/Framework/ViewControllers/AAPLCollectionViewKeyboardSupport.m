//
//  AAPLCollectionViewKeyboardSupport.m
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 6/18/15.
//  Copyright © 2015 Apple. All rights reserved.
//

#import "AAPLCollectionViewKeyboardSupport.h"

@implementation UIView (AAPLKeyboardSupport)

- (BOOL)aapl_containsFirstResponder
{
    if (self.isFirstResponder) {
        return YES;
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview aapl_containsFirstResponder]) {
            return YES;
        }
    }
    
    return NO;
}

@end

@implementation UICollectionView (AAPLKeyboardSupport)

- (void)aapl_scrollFirstResponderCellToVisible:(BOOL)animated
{
    for (UICollectionViewCell *cell in self.visibleCells) {
        if (![cell.contentView aapl_containsFirstResponder]) { continue; }
        
        NSIndexPath *ip = [self indexPathForCell:cell];
        [self scrollToItemAtIndexPath:ip atScrollPosition:0 animated:animated];
        break;
    }
}

@end

#pragma mark -

@interface AAPLCollectionViewKeyboardSupport ()

/// We hold a weak reference to a collection view controller rather than a
/// collection view because keyboard avoidance should not happen within a
/// popover; we can easily suss that case out on a view controller.
@property (nonatomic, weak) UICollectionViewController *collectionViewController;
@property (nonatomic) CGFloat keyboardOverlap;
@property (nonatomic) CGFloat keyboardDelta;
@property (nonatomic) BOOL trackFirstResponderEnabled;

@end

@implementation AAPLCollectionViewKeyboardSupport

- (instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithCollectionViewController:(UICollectionViewController *)collectionViewController {
    self = [super init];
    if (!self) { return nil; }
    self.collectionViewController = collectionViewController;
    return self;
}

/// This is a best effort at doing what UIPeripheralHost provides.
+ (CGFloat)overlapForView:(UIView *)view keyboardInfo:(NSDictionary *)userInfo
{
    UIWindow *window = view.window;
    if (window == nil || userInfo == nil) { return 0; }
    
    CGRect keyboardFrameScreen = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameWindow = [window convertRect:keyboardFrameScreen fromWindow:nil];
    CGRect keyboardFrameLocal = [window convertRect:keyboardFrameWindow toView:view.superview];
    CGRect coveredFrame = CGRectIntersection(view.frame, keyboardFrameLocal);
    CGRect finalOverlap = [window convertRect:coveredFrame toView:view.superview];
    return finalOverlap.size.height;
}

- (void)noteKeyboardWillShow:(NSNotification *)note
{
    [self adjustCollectionViewForKeyboardInfo:note.userInfo];

    UICollectionViewController *cvController = self.collectionViewController;
    if (cvController.popoverPresentationController == nil) {
        self.trackFirstResponderEnabled = YES;
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(adjustCollectionViewForKeyboardInfo:) object:nil];
}

- (void)noteKeyboardWillHide:(NSNotification *)note
{
    [self performSelector:@selector(adjustCollectionViewForKeyboardInfo:) withObject:nil afterDelay:0 inModes:@[ NSRunLoopCommonModes ]];
    
    UICollectionViewController *cvController = self.collectionViewController;
    if (cvController.popoverPresentationController == nil) {
        self.trackFirstResponderEnabled = YES;
    }
}

- (void)noteKeyboardAnimationCompleted:(NSNotification *)note
{
    self.trackFirstResponderEnabled = NO;
}

- (void)noteKeyboardDidChangeFrame:(NSNotification *)note
{
    [self adjustCollectionViewForKeyboardInfo:note.userInfo];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(adjustCollectionViewForKeyboardInfo:) object:nil];
}

- (void)adjustCollectionViewForKeyboardInfo:(NSDictionary *)userInfo
{
    if (self.viewIsDisappearing) { return; }
    
    UICollectionViewController *cvController = self.collectionViewController;
    if (!cvController.isViewLoaded || cvController.popoverPresentationController != nil) { return; }
    
    UICollectionView *cv = cvController.collectionView;
    if (cv.window == nil) { return; }
    
    CGFloat lastOverlap = self.keyboardOverlap;
    CGFloat newOverlap = [self.class overlapForView:cv keyboardInfo:userInfo];
    if (newOverlap == lastOverlap) { return; }
    
    CGFloat lastDelta = self.keyboardDelta;
    CGFloat newDelta = newOverlap - lastOverlap;
    
    UIEdgeInsets newInsets = cv.contentInset;
    UIEdgeInsets newScrollInsets = cv.scrollIndicatorInsets;
    
    newInsets.bottom += newDelta;
    newScrollInsets.bottom += newDelta;
    
    void(^animations)(void) = ^{
        cv.contentInset = newInsets;
        cv.scrollIndicatorInsets = newScrollInsets;
    };
    
    if (userInfo != nil) {
        NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        UIViewAnimationOptions opts = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16;
        [UIView animateWithDuration:duration delay:0 options:opts animations:animations completion:NULL];
    } else {
        animations();
    }
    
    self.keyboardOverlap = newOverlap;
    self.keyboardDelta = lastDelta + newDelta;
    
    if (newOverlap > 0 && self.trackFirstResponderEnabled) {
        [cv aapl_scrollFirstResponderCellToVisible:YES];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    if (!self.trackFirstResponderEnabled) { return; }
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // don't create a new animation context, just go with the flow
        [self.collectionViewController.collectionView aapl_scrollFirstResponderCellToVisible:context.isAnimated];
    } completion:NULL];
}

@end
