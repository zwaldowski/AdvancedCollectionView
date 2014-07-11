//
//  UIView+AAPLAdditions.h
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 7/10/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CGGeometry.h>

@interface UIView (HBAdditions)

@property (nonatomic, readonly) CGFloat aapl_scale;

/** Adds a separator to a view with a given color.

 For whichever rect edge is passed, two layout constraint target items can
 be passed for the *opposite* pair of rect edges to define the edges to which
 the separator is aligned. For example, if you are adding a separator to the min
 Y edge, the left and right edges of the separator bind to the passed items.

 @param edge The corresponding rect edge for the separator line
 @param color The color of the separator, or nil for the app-wide tint color.
 @param constraintTarget The view to install the opposite axis constraints on.
 Must be a common ancestor of the receiver, oppositeLeadingItem,
 and oppositeTrailingItem, or nil for the receiving view.
 @param oppositeLeadingItem The view to bind the top or left edge to, or nil for
 the receiving view.
 @param oppositeTrailingItem The view to bind the bottom or right edge to, or
 nil for the receiving view.
 @return The added separator view.
 */
- (UIView *)aapl_addSeparatorToEdge:(CGRectEdge)edge color:(UIColor *)color oppositeAxisParent:(UIView *)constraintTarget leading:(id)oppositeLeadingItem trailing:(id)oppositeTrailingItem;

@end
