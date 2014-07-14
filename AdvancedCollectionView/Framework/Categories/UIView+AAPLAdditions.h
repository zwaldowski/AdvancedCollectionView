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

/// A screen-appropriate width for a hairline (i.e., screen pixel width)
@property (nonatomic, readonly) CGFloat aapl_hairlineWidth;

/** Adds a separator to a view with a given color.

 @param edge The corresponding rect edge for the separator line
 @param color The color of the separator, or nil for the app-wide tint color.
 @return The added separator view.
 */
- (UIView *)aapl_addSeparatorToEdge:(CGRectEdge)edge color:(UIColor *)color;

@end
