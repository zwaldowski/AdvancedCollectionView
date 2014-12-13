/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A header view with a UISegmentedControl for displaying the titles of child data sources in a segmented data source.
  
 */

#import "AAPLSegmentedHeaderView.h"

@interface AAPLSegmentedHeaderView ()
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) NSArray *segmentedControlConstraints;
@end

@implementation AAPLSegmentedHeaderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    _segmentedControl = [[UISegmentedControl alloc] initWithFrame:CGRectZero];
    _segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [_segmentedControl setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
    [self addSubview:_segmentedControl];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_segmentedControl removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
}

- (UIEdgeInsets)defaultPadding
{
    return UIEdgeInsetsMake(10, 15, 10, 15);
}

- (NSArray *)constraintsForSegmentedControl
{
    UIEdgeInsets padding = self.padding;
    NSDictionary *views = NSDictionaryOfVariableBindings(_segmentedControl);
    NSDictionary *metrics = @{
                              @"TopMargin" : @(padding.top),
                              @"LeftMargin" : @(padding.left),
                              @"BottomMargin" : @(padding.bottom),
                              @"RightMargin" : @(padding.right)
                              };

    NSMutableArray *constraints = [NSMutableArray array];

    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-TopMargin-[_segmentedControl]-BottomMargin-|" options:0 metrics:metrics views:views]];

    if (isPad) {
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationLessThanOrEqual toItem:self attribute:NSLayoutAttributeWidth multiplier:1 constant:-(padding.left + padding.right)]];
    }
    else
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-LeftMargin-[_segmentedControl]-RightMargin-|" options:0 metrics:metrics views:views]];
    
    return constraints;
}

- (void)updateConstraints
{
    if (_segmentedControlConstraints) {
        [super updateConstraints];
        return;
    }

    _segmentedControlConstraints = [self constraintsForSegmentedControl];
    [self addConstraints:_segmentedControlConstraints];
    
    [super updateConstraints];
}

- (void)setNeedsUpdateConstraints
{
    if (_segmentedControlConstraints)
        [self removeConstraints:_segmentedControlConstraints];
    _segmentedControlConstraints = nil;
    [super setNeedsUpdateConstraints];
}

@end
