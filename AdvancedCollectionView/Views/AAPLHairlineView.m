/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A view with hairline thickness, either vertical or horizontal.
  
 */

#import "AAPLHairlineView.h"

#define HAIRLINE_COLOR 204.0/255.0

@interface AAPLHairlineView ()
@property (nonatomic) AAPLHairlineAlignment alignment;
@end

@implementation AAPLHairlineView

+ (AAPLHairlineView *)hairlineViewForAlignment:(AAPLHairlineAlignment)alignment
{
    AAPLHairlineView *view = [[self alloc] initWithFrame:CGRectZero];
    view.alignment = alignment;
    return view;
}

- (instancetype)init
{
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;
    self.backgroundColor = [UIColor colorWithWhite:HAIRLINE_COLOR alpha:1];
    self.alignment = AAPLHairlineAlignmentHorizontal;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self)
        return nil;
    self.backgroundColor = [UIColor colorWithWhite:HAIRLINE_COLOR alpha:1];
    self.alignment = AAPLHairlineAlignmentHorizontal;
    return self;
}

- (CGFloat)thickness
{
    return [[UIScreen mainScreen] scale] > 1 ? 0.5 : 1.0;
}

- (void)setFrame:(CGRect)frame
{
    CGFloat hairline = self.thickness;
    if (CGRectGetWidth(frame) > CGRectGetHeight(frame)) {
        frame.size.height = hairline;
        _alignment = AAPLHairlineAlignmentHorizontal;
        [self setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    }
    else {
        frame.size.width = hairline;
        _alignment = AAPLHairlineAlignmentHorizontal;
        [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [self setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    }
    [super setFrame:frame];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGFloat hairline = self.thickness;
    if (size.width > size.height)
        size.height = hairline;
    else
        size.width = hairline;
    return size;
}

- (CGSize)intrinsicContentSize
{
    if (AAPLHairlineAlignmentHorizontal == _alignment)
        return CGSizeMake(UIViewNoIntrinsicMetric, self.thickness);
    else
        return CGSizeMake(self.thickness, UIViewNoIntrinsicMetric);
}
@end
