/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A pinnable header subclass of UICollectionReusableView.
  
 */

#import "AAPLPinnableHeaderView.h"
#import "AAPLCollectionViewGridLayout_Private.h"
#import "AAPLHairlineView.h"

@interface AAPLPinnableHeaderView ()
@property (nonatomic, readwrite) BOOL pinned;
@property (nonatomic, strong) AAPLHairlineView *borderView;
@property (nonatomic, strong) UIColor *backgroundColorBeforePinning;
@end

@implementation AAPLPinnableHeaderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    self.backgroundColor = [UIColor whiteColor];

    _bottomBorderColor = [UIColor colorWithWhite:204/255.0 alpha:1];
    _bottomBorderColorWhenPinned = [UIColor colorWithWhite:204/255.0 alpha:1];

    _borderView = [[AAPLHairlineView alloc] initWithFrame:CGRectZero];
    _borderView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_borderView];

    NSMutableArray *constraints = [NSMutableArray array];
    NSDictionary *views = NSDictionaryOfVariableBindings(_borderView);

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_borderView]|" options:0 metrics:nil views:views]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_borderView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];

    [self addConstraints:constraints];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _pinned = NO;
    _bottomBorderColor = [UIColor colorWithWhite:204/255.0 alpha:1];
    _bottomBorderColorWhenPinned = [UIColor colorWithWhite:204/255.0 alpha:1];
    _backgroundColorWhenPinned = nil;
}

- (UIEdgeInsets)defaultPadding
{
    return UIEdgeInsetsZero;
}

- (void)setPadding:(UIEdgeInsets)padding
{
    if (UIEdgeInsetsEqualToEdgeInsets(padding, _padding))
        return;
    _padding = padding;
    [self setNeedsUpdateConstraints];
}

- (void)setBottomBorderColor:(UIColor *)bottomBorderColor
{
    _bottomBorderColor = bottomBorderColor;
    if (!self.pinned) {
        _borderView.backgroundColor = bottomBorderColor;
        _borderView.hidden = bottomBorderColor ? NO : YES;
    }
}

- (void)setBottomBorderColorWhenPinned:(UIColor *)bottomBorderColorWhenPinned
{
    _bottomBorderColorWhenPinned = bottomBorderColorWhenPinned;
    if (self.pinned) {
        _borderView.backgroundColor = bottomBorderColorWhenPinned;
        _borderView.hidden = bottomBorderColorWhenPinned ? NO : YES;
    }
}

- (void)applyLayoutAttributes:(AAPLCollectionViewGridLayoutAttributes *)layoutAttributes
{
    if (![layoutAttributes isKindOfClass:[AAPLCollectionViewGridLayoutAttributes class]])
        return;

    self.hidden = layoutAttributes.hidden;
    self.userInteractionEnabled = !layoutAttributes.editing;

    if (UIEdgeInsetsEqualToEdgeInsets(layoutAttributes.padding, UIEdgeInsetsZero))
        self.padding = self.defaultPadding;
    else
        self.padding = layoutAttributes.padding;

    // If we're not pinned, then immediately set the background colour, otherwise, remember it for when we restore the background color
    if (!_pinned)
        self.backgroundColor = layoutAttributes.backgroundColor;
    else
        _backgroundColorBeforePinning = layoutAttributes.backgroundColor;

    BOOL isPinned = layoutAttributes.pinnedHeader;

    if (isPinned != _pinned)
        [UIView animateWithDuration:0.25 animations:^{
            if (isPinned) {
                _backgroundColorBeforePinning = self.backgroundColor;
                if (self.backgroundColorWhenPinned)
                    self.backgroundColor = self.backgroundColorWhenPinned;
            }
            else {
                self.backgroundColor = _backgroundColorBeforePinning;
            }

            self.pinned = isPinned;

            BOOL showBorder = YES;
            UIColor *borderColor = self.bottomBorderColor;

            if (isPinned && self.bottomBorderColorWhenPinned)
                borderColor = self.bottomBorderColorWhenPinned;

            if (!borderColor)
                showBorder = NO;
            
            _borderView.backgroundColor = borderColor;
            _borderView.hidden = !showBorder;
        }];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.highlighted = YES;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.highlighted = NO;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.highlighted = NO;
}

@end
