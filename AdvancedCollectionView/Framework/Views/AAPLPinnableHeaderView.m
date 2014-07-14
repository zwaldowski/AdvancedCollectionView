/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLPinnableHeaderView.h"
#import "AAPLCollectionViewGridLayout.h"
#import "UIView+AAPLAdditions.h"

@interface AAPLPinnableHeaderView ()
@property (nonatomic) BOOL pinned;
@property (nonatomic) UIView *borderView;
@property (nonatomic) UIColor *backgroundColorBeforePinning;
@end

@implementation AAPLPinnableHeaderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    self.backgroundColor = [UIColor whiteColor];

    _bottomBorderColor = [UIColor colorWithWhite:0.8 alpha:1];
    _bottomBorderColorWhenPinned = [UIColor colorWithWhite:0.8 alpha:1];
	_borderView = [self aapl_addSeparatorToEdge:CGRectMaxYEdge color:_bottomBorderColor];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _pinned = NO;
    _bottomBorderColor = [UIColor colorWithWhite:0.8 alpha:1];
    _bottomBorderColorWhenPinned = [UIColor colorWithWhite:0.8 alpha:1];
	_borderView.backgroundColor = _bottomBorderColor;
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
        _borderView.hidden = (bottomBorderColor == nil);
    }
}

- (void)setBottomBorderColorWhenPinned:(UIColor *)bottomBorderColorWhenPinned
{
    _bottomBorderColorWhenPinned = bottomBorderColorWhenPinned;
    if (self.pinned) {
        _borderView.backgroundColor = bottomBorderColorWhenPinned;
        _borderView.hidden = (bottomBorderColorWhenPinned == nil);
    }
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)regularLayoutAttributes {
	self.hidden = regularLayoutAttributes.hidden;
	self.userInteractionEnabled = YES;

	AAPLCollectionViewGridLayoutAttributes *layoutAttributes = (AAPLCollectionViewGridLayoutAttributes *)regularLayoutAttributes;
	if (![layoutAttributes isKindOfClass:AAPLCollectionViewGridLayoutAttributes.class])
		return;

	if (UIEdgeInsetsEqualToEdgeInsets(layoutAttributes.padding, UIEdgeInsetsZero)) {
		self.padding = self.defaultPadding;
	} else {
		self.padding = layoutAttributes.padding;
	}

    // If we're not pinned, then immediately set the background colour, otherwise, remember it for when we restore the background color
    if (!_pinned)
        self.backgroundColor = layoutAttributes.backgroundColor;
    else
        _backgroundColorBeforePinning = layoutAttributes.backgroundColor;

    BOOL isPinned = layoutAttributes.pinnedHeader;

	if (isPinned != _pinned) {
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
}

@end
