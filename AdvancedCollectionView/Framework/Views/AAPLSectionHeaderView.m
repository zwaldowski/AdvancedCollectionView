/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A header view with a text label on the left  right. Also an optional button on the right.
 */

#import "AAPLSectionHeaderView.h"
#import "AAPLTheme.h"

@interface AAPLSectionHeaderView ()
@property (nonatomic, readwrite, strong) UILabel *leftLabel;
@property (nonatomic, readwrite, strong) UILabel *rightLabel;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@property (nonatomic, strong) NSLayoutConstraint *rightLabelMarginConstraint;
@end

@implementation AAPLSectionHeaderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    _leftLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _leftLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:_leftLabel];

    _rightLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _rightLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_rightLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self addSubview:_rightLabel];

    UIView *container = self;
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_leftLabel attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:container attribute:NSLayoutAttributeLeadingMargin multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_leftLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:container attribute:NSLayoutAttributeTopMargin multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_leftLabel attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:container attribute:NSLayoutAttributeBottomMargin multiplier:1 constant:0]];

    [constraints addObject:[NSLayoutConstraint constraintWithItem:_rightLabel attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:_leftLabel attribute:NSLayoutAttributeTrailing multiplier:1 constant:10]];

    [constraints addObject:[NSLayoutConstraint constraintWithItem:_leftLabel attribute:NSLayoutAttributeBaseline relatedBy:NSLayoutRelationEqual toItem:_rightLabel attribute:NSLayoutAttributeBaseline multiplier:1 constant:0]];

    _rightLabelMarginConstraint = [NSLayoutConstraint constraintWithItem:_rightLabel attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:container attribute:NSLayoutAttributeTrailingMargin multiplier:1 constant:0];
    [constraints addObject:_rightLabelMarginConstraint];

    [self addConstraints:constraints];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_actionButton removeFromSuperview];
    _actionButton = nil;
    _leftLabel.text = nil;
    _rightLabel.text = nil;
}

- (UIEdgeInsets)defaultLayoutMargins
{
    return UIEdgeInsetsMake(15, 15, 10, 15);
}

- (NSString *)leftText
{
    return _leftLabel.text;
}

- (void)setLeftText:(NSString *)leftText
{
    _leftLabel.text = leftText;
}

- (NSString *)rightText
{
    return _rightLabel.text;
}

- (void)setRightText:(NSString *)rightText
{
    _rightLabel.text = rightText;
    _actionButton.contentHorizontalAlignment = rightText.length ? UIControlContentHorizontalAlignmentLeft : UIControlContentHorizontalAlignmentRight;
}

- (void)setTheme:(AAPLTheme *)theme
{
    BOOL changed = (self.theme != theme);
    [super setTheme:theme];
    if (changed) {
        _leftLabel.font = theme.sectionHeaderFont;
        _rightLabel.font = theme.sectionHeaderSmallFont;
        _actionButton.titleLabel.font = theme.sectionHeaderSmallFont;
    }
}

- (UIButton *)actionButton
{
    if (_actionButton)
        return _actionButton;

    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_actionButton setTitleColor:self.theme.mediumGreyTextColor forState:UIControlStateDisabled];
    [self addSubview:_actionButton];

    NSLayoutConstraint *actionButtonRightMargin = [NSLayoutConstraint constraintWithItem:_actionButton attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTrailingMargin multiplier:1 constant:0];
    NSLayoutConstraint *actionButtonLeftMargin = [NSLayoutConstraint constraintWithItem:_actionButton attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_rightLabel attribute:NSLayoutAttributeTrailing multiplier:1 constant:5];
    NSLayoutConstraint *actionButtonBaseline = [NSLayoutConstraint constraintWithItem:_actionButton attribute:NSLayoutAttributeBaseline relatedBy:NSLayoutRelationEqual toItem:_rightLabel attribute:NSLayoutAttributeBaseline multiplier:1 constant:0];

    _rightLabelMarginConstraint.active = NO;
    actionButtonLeftMargin.active = YES;
    actionButtonRightMargin.active = YES;
    actionButtonBaseline.active = YES;
    
    return _actionButton;
}
@end
