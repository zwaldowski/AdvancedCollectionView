/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A view with hairline thickness, either vertical or horizontal.
  
 */

#import "AAPLHairlineView.h"
#import "UIView+Helpers.h"

NS_INLINE UIColor *hairlineColor(void) {
    return [UIColor colorWithWhite:0.8f alpha:1];
}

@interface AAPLHairlineView ()
@property (nonatomic) UILayoutConstraintAxis axis;
@end

@implementation AAPLHairlineView

- (void)commonInit
{
    self.backgroundColor = hairlineColor();
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) { return nil; }
    [self commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) { return nil; }
    [self commonInit];
    return self;
}

- (void)setFrame:(CGRect)frame
{
    CGFloat hairline = self.aapl_hairline;
    UILayoutConstraintAxis axis;
    
    if (CGRectGetWidth(frame) > CGRectGetHeight(frame)) {
        frame.size.height = hairline;
        axis = UILayoutConstraintAxisHorizontal;
    } else {
        frame.size.width = hairline;
        axis = UILayoutConstraintAxisVertical;
    }
    
    self.axis = axis;

    UILayoutConstraintAxis alternate = axis == UILayoutConstraintAxisHorizontal ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    [self setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:axis];
    [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:alternate];
    
    [super setFrame:frame];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGFloat hairline = self.aapl_hairline;
    if (size.width > size.height)
        size.height = hairline;
    else
        size.width = hairline;
    return size;
}

- (CGSize)intrinsicContentSize
{
    CGFloat hairline = self.aapl_hairline;
    if (self.axis == UILayoutConstraintAxisHorizontal) {
        return CGSizeMake(UIViewNoIntrinsicMetric, hairline);
    } else {
        return CGSizeMake(hairline, UIViewNoIntrinsicMetric);
    }
}

@end
