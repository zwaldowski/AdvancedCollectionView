/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The header view shown in the cat detail screen. This view shows the name of the cat, its conservation status, and the favorite flag.
  
 */

#import "AAPLCatDetailHeader.h"
#import "AAPLCat.h"

@interface AAPLCatDetailHeader ()
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *shortDescription;
@property (nonatomic, strong) UILabel *conservationStatusValue;
@property (nonatomic, strong) UILabel *conservationStatusLabel;
@end

@implementation AAPLCatDetailHeader

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [UIFont systemFontOfSize:24];
    _nameLabel.numberOfLines = 1;
    [self addSubview:_nameLabel];

    _shortDescription = [[UILabel alloc] initWithFrame:CGRectZero];
    _shortDescription.translatesAutoresizingMaskIntoConstraints = NO;
    _shortDescription.font = [UIFont systemFontOfSize:14];
    _shortDescription.numberOfLines = 2;
    _shortDescription.textColor = [UIColor colorWithWhite:0.4 alpha:1];
    [self addSubview:_shortDescription];

    _conservationStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _conservationStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _conservationStatusLabel.font = [UIFont systemFontOfSize:12];
    _conservationStatusLabel.numberOfLines = 1;
    _conservationStatusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1];
    [self addSubview:_conservationStatusLabel];

    _conservationStatusValue = [[UILabel alloc] initWithFrame:CGRectZero];
    _conservationStatusValue.translatesAutoresizingMaskIntoConstraints = NO;
    _conservationStatusValue.font = [UIFont systemFontOfSize:12];
    _conservationStatusValue.numberOfLines = 1;
    _conservationStatusLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1];
    [self addSubview:_conservationStatusValue];

    NSDictionary *views = NSDictionaryOfVariableBindings(_nameLabel, _conservationStatusLabel, _conservationStatusValue, _shortDescription);
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_nameLabel]-|" options:0 metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_shortDescription]-|" options:0 metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"[_conservationStatusValue]-|" options:0 metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_conservationStatusLabel]-3-[_conservationStatusValue]" options:NSLayoutFormatAlignAllBaseline metrics:nil views:views]];

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[_nameLabel][_shortDescription]-3-[_conservationStatusValue]" options:0 metrics:nil views:views]];

    [self addConstraints:constraints];
    return self;
}

- (void)configureWithCat:(AAPLCat *)cat
{
    self.nameLabel.text = cat.name;
    self.conservationStatusValue.text = cat.conservationStatus;
    self.shortDescription.text = cat.shortDescription;
    if (cat.conservationStatus)
        self.conservationStatusLabel.text = NSLocalizedString(@"Conservation Status:", @"Conservation Status Label");
}

@end
