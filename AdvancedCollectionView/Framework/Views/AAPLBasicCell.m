/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A basic collection view cell with a primary and secondary label. When styled using AAPLBasicCellStyleDefault, the primary label is on the left and the secondary label is on the right. When styled with AAPLBasicCellStyleSubtitle, both the primary and secondar labels are on the left with the primary above the secondary.
 */

#import "AAPLBasicCell.h"
#import "AAPLTheme.h"

@interface AAPLBasicCell ()
@property (nonatomic, strong, readwrite) UILabel *primaryLabel;
@property (nonatomic, strong, readwrite) UILabel *secondaryLabel;
@property (nonatomic, strong) NSMutableArray *constraints;
@end

@implementation AAPLBasicCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    UIView *contentView = self.contentView;

    _primaryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _primaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _primaryLabel.numberOfLines = 1;
    [contentView addSubview:_primaryLabel];

    _secondaryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _secondaryLabel.numberOfLines = 1;
    [contentView addSubview:_secondaryLabel];

    return self;
}

- (void)setStyle:(AAPLBasicCellStyle)style
{
    if (style == _style)
        return;
    _style = style;

    switch (style) {
        case AAPLBasicCellStyleDefault:
            _primaryLabel.font = self.theme.listBodyFont;
            _secondaryLabel.font = self.theme.listBodyFont;
            break;

        case AAPLBasicCellStyleSubtitle:
            _primaryLabel.font = self.theme.listBodyFont;
            _secondaryLabel.font = self.theme.listSmallFont;
            break;
    }

    [self setNeedsUpdateConstraints];
}

- (void)updateConstraints
{
    if (_constraints) {
        [super updateConstraints];
        return;
    }

    CGFloat primaryLineHeight = _primaryLabel.font.lineHeight;

    UIView *contentView = self.contentView;

    _constraints = [NSMutableArray array];

    NSDictionary *views = NSDictionaryOfVariableBindings(_primaryLabel, _secondaryLabel);
    NSDictionary *metrics = @{
                              @"Left" : @(self.layoutMargins.left),
                              @"Right" : @(self.layoutMargins.right),
                              };

    if (AAPLBasicCellStyleDefault == _style) {
        [_constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-Left-[_primaryLabel]-(>=10)-[_secondaryLabel]-Right-|" options:NSLayoutFormatAlignAllBaseline metrics:metrics views:views]];
        [_constraints addObject:[NSLayoutConstraint constraintWithItem:_primaryLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        [_constraints addObject:[NSLayoutConstraint constraintWithItem:_primaryLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationLessThanOrEqual toItem:contentView attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
    }
    else {
        [_constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-Left-[_primaryLabel]-(>=Right)-|" options:0 metrics:metrics views:views]];
        [_constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-Left-[_secondaryLabel]-(>=Right)-|" options:0 metrics:metrics views:views]];

        [_constraints addObject:[NSLayoutConstraint constraintWithItem:_primaryLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1 constant:0.2 * primaryLineHeight]];
        [_constraints addObject:[NSLayoutConstraint constraintWithItem:_secondaryLabel attribute:NSLayoutAttributeFirstBaseline relatedBy:NSLayoutRelationEqual toItem:_primaryLabel attribute:NSLayoutAttributeLastBaseline multiplier:1 constant:1.1 * primaryLineHeight]];
        [_constraints addObject:[NSLayoutConstraint constraintWithItem:_secondaryLabel attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeBottom multiplier:1 constant:-0.2 * primaryLineHeight]];
    }

    [contentView addConstraints:_constraints];
    [super updateConstraints];
}

- (void)setNeedsUpdateConstraints
{
    if (_constraints)
        [self.contentView removeConstraints:_constraints];
    _constraints = nil;
    [super setNeedsUpdateConstraints];
}

@end
