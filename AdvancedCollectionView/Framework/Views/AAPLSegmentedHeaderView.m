/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A header view with a UISegmentedControl for displaying the titles of child data sources in a segmented data source.
 */

#import "AAPLSegmentedHeaderView.h"

@interface AAPLSegmentedHeaderView ()
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) NSLayoutConstraint *segmentedControlLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *segmentedControlTrailingConstraint;
@property (nonatomic, strong) NSArray *alignmentConstraints;
@end

@implementation AAPLSegmentedHeaderView

- (instancetype)initWithFrame:(CGRect)frame headerAlignment:(AAPLSegmentedHeaderAlignment)headerAlignment
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    _headerAlignment = headerAlignment;

    _segmentedControl = [[UISegmentedControl alloc] initWithFrame:CGRectZero];
    _segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [_segmentedControl setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
    [_segmentedControl setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self addSubview:_segmentedControl];

    _segmentedControlLeadingConstraint = [NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeadingMargin multiplier:1 constant:0];
    _segmentedControlTrailingConstraint = [NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTrailingMargin multiplier:1 constant:0];

    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTopMargin multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottomMargin multiplier:1 constant:0]];

    _alignmentConstraints = [self alignmentConstraintsForHeaderAlignment:_headerAlignment];
    [constraints addObjectsFromArray:_alignmentConstraints];

    [self addConstraints:constraints];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame headerAlignment:AAPLSegmentedHeaderAlignmentCenter];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self)
        return nil;
    _headerAlignment = AAPLSegmentedHeaderAlignmentCenter;
    return self;
}

- (NSArray *)alignmentConstraintsForHeaderAlignment:(AAPLSegmentedHeaderAlignment)headerAlignment
{
    NSArray *alignmentConstraints = nil;
    switch (headerAlignment) {
        case AAPLSegmentedHeaderAlignmentCenter:
            alignmentConstraints = @[[NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterXWithinMargins multiplier:1 constant:0]];
            break;

        case AAPLSegmentedHeaderAlignmentLeading:
            alignmentConstraints = @[
                                     [NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeadingMargin multiplier:1 constant:0],
                                     [NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationLessThanOrEqual toItem:self attribute:NSLayoutAttributeTrailingMargin multiplier:1 constant:0]
                                     ];
            break;

        case AAPLSegmentedHeaderAlignmentTrailing:
            alignmentConstraints = @[
                                     [NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self attribute:NSLayoutAttributeLeadingMargin multiplier:1 constant:0],
                                     [NSLayoutConstraint constraintWithItem:_segmentedControl attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTrailingMargin multiplier:1 constant:0]
                                     ];
            break;
    }

    return alignmentConstraints;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_segmentedControl removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
}

- (void)setHeaderAlignment:(AAPLSegmentedHeaderAlignment)headerAlignment
{
    if (_headerAlignment == headerAlignment)
        return;
    _headerAlignment = headerAlignment;

    if (_alignmentConstraints)
        [self removeConstraints:_alignmentConstraints];
    _alignmentConstraints = [self alignmentConstraintsForHeaderAlignment:headerAlignment];
    [self addConstraints:_alignmentConstraints];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = self.frame.size.width;
    CGFloat segmentedControlWidth = self.segmentedControl.frame.size.width;
    UIEdgeInsets layoutMargins = self.layoutMargins;

    // If the segmented control is wider than the width of the header minus twice the layout margins, then snap to the layout margins.
    BOOL enableMarginConstraints = segmentedControlWidth > (width - 2*(layoutMargins.left + layoutMargins.right));
    _segmentedControlLeadingConstraint.active = enableMarginConstraints;
    _segmentedControlTrailingConstraint.active = enableMarginConstraints;
    [super layoutSubviews];
}

- (UIEdgeInsets)defaultLayoutMargins
{
    return UIEdgeInsetsMake(8, 15, 10, 15);
}

@end
