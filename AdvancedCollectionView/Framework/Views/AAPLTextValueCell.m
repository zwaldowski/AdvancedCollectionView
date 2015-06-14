/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A simple AAPLCollectionViewCell that displays a large block of text.
 */

#import "AAPLTextValueCell.h"
#import "AAPLTheme.h"
#import "AAPLLabel.h"

@interface AAPLTextValueCell ()
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) AAPLLabel *label;
@end

@implementation AAPLTextValueCell
@synthesize numberOfLines = _numberOfLines;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    UIView *contentView = self.contentView;

    _title = [[UILabel alloc] initWithFrame:CGRectZero];
    _title.translatesAutoresizingMaskIntoConstraints = NO;
    _title.numberOfLines = 1;
    [contentView addSubview:_title];

    _label = [[AAPLLabel alloc] initWithFrame:CGRectZero];
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    _label.lineBreakMode = NSLineBreakByWordWrapping;
    _label.numberOfLines = 0;
    [contentView addSubview:_label];

    NSMutableArray *constraints = [NSMutableArray array];
    NSDictionary *views = NSDictionaryOfVariableBindings(_label, _title);

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_title]-|" options:0 metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_label]-|" options:0 metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[_title]-[_label]-|" options:0 metrics:nil views:views]];

    [contentView addConstraints:constraints];

    return self;
}

- (NSInteger)numberOfLines
{
    return _numberOfLines;
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
    _numberOfLines = numberOfLines;
    if (_shouldAllowTruncation)
        _label.numberOfLines = numberOfLines;
}

- (void)setShouldAllowTruncation:(BOOL)shouldAllowTruncation
{
    _shouldAllowTruncation = shouldAllowTruncation;
    if (shouldAllowTruncation)
        _label.numberOfLines = _numberOfLines;
    else
        _label.numberOfLines = 0;
}

- (void)configureWithTitle:(NSString *)title text:(NSString *)text
{
    _title.font = self.theme.sectionHeaderFont;
    _title.text = title;

    _label.font = self.theme.bodyFont;
    _label.textColor = self.theme.darkGreyTextColor;
    _label.text = text;
}

- (void)layoutSubviews
{
    CGRect bounds = self.bounds;
    _label.preferredMaxLayoutWidth = CGRectGetWidth(bounds) - 30;
    [super layoutSubviews];
}

@end
