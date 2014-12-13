/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of AAPLCollectionViewCell that displays an AAPLCatSighting instance.
  
 */

#import "AAPLCatSightingCell.h"
#import "AAPLCatSighting.h"

@interface AAPLCatSightingCell ()
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *fancierLabel;
@property (nonatomic, strong) UILabel *shortDescriptionLabel;
@end

@implementation AAPLCatSightingCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    UIView *contentView = self.contentView;

    _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _dateLabel.font = [UIFont systemFontOfSize:12];
    _dateLabel.textColor = [UIColor colorWithWhite:0.6f alpha:1];
    [_dateLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    [contentView addSubview:_dateLabel];

    _fancierLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _fancierLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _fancierLabel.font = [UIFont systemFontOfSize:14];

    [contentView addSubview:_fancierLabel];

    _shortDescriptionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _shortDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _shortDescriptionLabel.font = [UIFont systemFontOfSize:10];
    _shortDescriptionLabel.textColor = [UIColor colorWithWhite:0.4f alpha:1];

    [contentView addSubview:_shortDescriptionLabel];

    NSMutableArray *constraints = [NSMutableArray array];
    NSDictionary *views = NSDictionaryOfVariableBindings(_dateLabel, _fancierLabel, _shortDescriptionLabel);

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_fancierLabel]-[_dateLabel]-|" options:NSLayoutFormatAlignAllBaseline metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_shortDescriptionLabel]-|" options:0 metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-3-[_fancierLabel][_shortDescriptionLabel]-3-|" options:0 metrics:nil views:views]];

    [contentView addConstraints:constraints];

    return self;
}

- (void)configureWithCatSighting:(AAPLCatSighting *)catSighting dateFormatter:(NSDateFormatter *)dateFormatter
{
    self.dateLabel.text = [dateFormatter stringFromDate:catSighting.date];
    self.fancierLabel.text = catSighting.catFancier;
    self.shortDescriptionLabel.text = catSighting.shortDescription;
}
@end
