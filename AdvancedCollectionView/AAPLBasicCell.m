/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A basic collection view cell with a primary and secondary label. When styled using AAPLBasicCellStyleDefault, the primary label is on the left and the secondary label is on the right. When styled with AAPLBasicCellStyleSubtitle, both the primary and secondar labels are on the left with the primary above the secondary.
  
 */

#import "AAPLBasicCell.h"

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
    UIFont *defaultFont = [UIFont systemFontOfSize:12];

    _primaryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _primaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _primaryLabel.numberOfLines = 1;
    _primaryLabel.font = defaultFont;
    [contentView addSubview:_primaryLabel];

    _secondaryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _secondaryLabel.numberOfLines = 1;
    _secondaryLabel.font = defaultFont;
    [contentView addSubview:_secondaryLabel];

    return self;
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets
{
    if (UIEdgeInsetsEqualToEdgeInsets(contentInsets, _contentInsets))
        return;
    _contentInsets = contentInsets;
    [self setNeedsUpdateConstraints];
}

- (void)setStyle:(AAPLBasicCellStyle)style
{
    if (style == _style)
        return;
    _style = style;

    [self setNeedsUpdateConstraints];
}

- (void)updateConstraints
{
    if (_constraints) {
        [super updateConstraints];
        return;
    }

    CGFloat labelHeight;

    if (AAPLBasicCellStyleDefault == _style)
        labelHeight = MAX(_primaryLabel.font.lineHeight, _secondaryLabel.font.lineHeight);
    else
        labelHeight = _primaryLabel.font.lineHeight + _secondaryLabel.font.lineHeight;

    // Our content insets are based on a 44pt row height
    CGFloat verticalPadding = (44 - labelHeight)/2;

    _contentInsets = UIEdgeInsetsMake(verticalPadding, 15, verticalPadding, 15);
    
    UIView *contentView = self.contentView;

    _constraints = [NSMutableArray array];

    NSDictionary *views = NSDictionaryOfVariableBindings(_primaryLabel, _secondaryLabel);
    NSDictionary *metrics = @{
                              @"Left" : @(_contentInsets.left),
                              @"Top" : @(_contentInsets.top),
                              @"Right" : @(_contentInsets.right),
                              @"Bottom" : @(_contentInsets.bottom)
                              };

    if (AAPLBasicCellStyleDefault == _style) {
        [_constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-Left-[_primaryLabel]-(>=10)-[_secondaryLabel]-Right-|" options:NSLayoutFormatAlignAllBaseline metrics:metrics views:views]];
        [_constraints addObject:[NSLayoutConstraint constraintWithItem:_primaryLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        [_constraints addObject:[NSLayoutConstraint constraintWithItem:_primaryLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationLessThanOrEqual toItem:contentView attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
    }
    else {
        [_constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-Left-[_primaryLabel]-(>=Right)-|" options:0 metrics:metrics views:views]];
        [_constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-Left-[_secondaryLabel]-(>=Right)-|" options:0 metrics:metrics views:views]];
        [_constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-Top-[_primaryLabel][_secondaryLabel]-Bottom-|" options:0 metrics:metrics views:views]];
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
