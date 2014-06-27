/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A view with hairline thickness, either vertical or horizontal.
  
*/

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, AAPLHairlineAlignment) {
    /// A hairline view that is horizontal
    AAPLHairlineAlignmentHorizontal,
    /// A hairline view that is vertical
    AAPLHairlineAlignmentVertical
};

/// A simple view that is ALWAYS a hairline thickness, either in width or height. By default the background color is a medium grey.
@interface AAPLHairlineView : UIView

/// A convenience for accessing the thickness of the hairline view. This will always be the inverse of the scale of the main display. For example, on an iPhone 5S, this will be 0.5. On a first generation iPad mini, this would be 1.0.
@property (nonatomic, readonly) CGFloat thickness;

/// Create a new hairline view with the specified alignment.
+ (AAPLHairlineView *)hairlineViewForAlignment:(AAPLHairlineAlignment)alignment;

@end
