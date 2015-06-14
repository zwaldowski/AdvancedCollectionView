/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The header view shown in the cat detail screen. This view shows the name of the cat, its conservation status, and the favorite flag.
 */

#import "AAPLCatDetailHeader.h"
#import "AAPLCat.h"

#import "UIView+Helpers.h"

@interface NSObject ()
- (void)toggleFavorite:(id)sender;
@end

@interface AAPLCatDetailHeader ()
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *shortDescription;
@property (nonatomic, strong) UILabel *conservationStatusValue;
@property (nonatomic, strong) UILabel *conservationStatusLabel;
@property (nonatomic, strong) UIButton *favoriteButton;
@property (nonatomic, getter = isFavorite) BOOL favorite;
@end

@implementation AAPLCatDetailHeader

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    UIFontDescriptor *headerDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleHeadline];
    CGFloat headerFontSize = ceil(headerDescriptor.pointSize * 1.411);
    UIFont *headerFont = [UIFont fontWithDescriptor:headerDescriptor size:headerFontSize];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = headerFont;
    _nameLabel.numberOfLines = 1;
    [self addSubview:_nameLabel];

    _shortDescription = [[UILabel alloc] initWithFrame:CGRectZero];
    _shortDescription.translatesAutoresizingMaskIntoConstraints = NO;
    _shortDescription.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _shortDescription.numberOfLines = 3;
    _shortDescription.textColor = [UIColor colorWithWhite:0.4 alpha:1];
    [_shortDescription setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    [self addSubview:_shortDescription];

    _conservationStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _conservationStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _conservationStatusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _conservationStatusLabel.numberOfLines = 1;
    _conservationStatusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1];
    [_conservationStatusLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self addSubview:_conservationStatusLabel];

    _conservationStatusValue = [[UILabel alloc] initWithFrame:CGRectZero];
    _conservationStatusValue.translatesAutoresizingMaskIntoConstraints = NO;
    _conservationStatusValue.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _conservationStatusValue.numberOfLines = 1;
    _conservationStatusLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1];
    [_conservationStatusLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self addSubview:_conservationStatusValue];

    _favoriteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _favoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_favoriteButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_favoriteButton setImage:[UIImage imageNamed:@"NotFavorite"] forState:UIControlStateNormal];
    [_favoriteButton addTarget:self action:@selector(favoriteTapped:) forControlEvents:UIControlEventTouchUpInside];

    [self addSubview:_favoriteButton];

    NSDictionary *views = NSDictionaryOfVariableBindings(_nameLabel, _conservationStatusLabel, _conservationStatusValue, _favoriteButton, _shortDescription);
    const CGFloat buttonSize = 44;
    const CGFloat linespacing = ceil(_shortDescription.font.lineHeight * 1.111); // 20pt

    NSDictionary *metrics = @{
                              @"FavoriteRightMargin" : @(MAX(0.0, 15.0 - floor((buttonSize - _favoriteButton.imageView.image.size.width) / 2))),
                              @"FavoriteTopMargin" : @(MAX(0.0, 15.0 - floor((buttonSize - _favoriteButton.imageView.image.size.height) / 2))),
                              };
    NSMutableArray *constraints = [NSMutableArray array];

    [constraints addObject:[NSLayoutConstraint constraintWithItem:_favoriteButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:buttonSize]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_favoriteButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:buttonSize]];

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-15-[_nameLabel]-[_favoriteButton]-FavoriteRightMargin-|" options:0 metrics:metrics views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-15-[_shortDescription]-[_favoriteButton]-FavoriteRightMargin-|" options:0 metrics:metrics views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[_conservationStatusValue]-[_favoriteButton]-FavoriteRightMargin-|" options:0 metrics:metrics views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-15-[_conservationStatusLabel]-3-[_conservationStatusValue]" options:0 metrics:metrics views:views]];

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-10-[_nameLabel]" options:0 metrics:metrics views:views]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_shortDescription attribute:NSLayoutAttributeFirstBaseline relatedBy:NSLayoutRelationEqual toItem:_nameLabel attribute:NSLayoutAttributeLastBaseline multiplier:1.0 constant:linespacing]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_conservationStatusLabel attribute:NSLayoutAttributeFirstBaseline relatedBy:NSLayoutRelationEqual toItem:_shortDescription attribute:NSLayoutAttributeLastBaseline multiplier:1 constant:linespacing]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_conservationStatusLabel attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1 constant:-20]];

    [constraints addObject:[NSLayoutConstraint constraintWithItem:_conservationStatusValue attribute:NSLayoutAttributeFirstBaseline relatedBy:NSLayoutRelationEqual toItem:_shortDescription attribute:NSLayoutAttributeLastBaseline multiplier:1 constant:linespacing]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_conservationStatusValue attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1 constant:-20]];

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-FavoriteTopMargin-[_favoriteButton]" options:0 metrics:metrics views:views]];

    [self addConstraints:constraints];
    return self;
}

- (void)setFavorite:(BOOL)favorite
{
    if (_favorite == favorite)
        return;

    _favorite = favorite;

    UIImage *image;
    if (favorite)
        image = [UIImage imageNamed:@"Favorite"];
    else
        image = [UIImage imageNamed:@"NotFavorite"];

    [_favoriteButton setImage:image forState:UIControlStateNormal];
}

- (void)configureWithCat:(AAPLCat *)cat
{
    self.nameLabel.text = cat.name;
    self.conservationStatusValue.text = cat.conservationStatus ?: @" ";
    self.shortDescription.text = cat.shortDescription;
    if (cat.conservationStatus)
        self.conservationStatusLabel.text = NSLocalizedString(@"Conservation Status:", @"Conservation Status Label");
    else
        self.conservationStatusLabel.text = @" ";

    self.favorite = cat.favorite;

    [self.conservationStatusLabel invalidateIntrinsicContentSize];
    [self.shortDescription invalidateIntrinsicContentSize];
}

- (void)favoriteTapped:(id)sender
{
    self.favorite = !self.favorite;

    [self aapl_sendAction:@selector(toggleFavorite:)];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat availableLabelWidth = self.shortDescription.frame.size.width;
    self.shortDescription.preferredMaxLayoutWidth = availableLabelWidth;
    
    [super layoutSubviews];
}

@end
