/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "UICollectionReusableView+AAPLGridLayout.h"

static inline BOOL collectionViewSupportsConstraints()
{
    static BOOL constraintsSupported;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		constraintsSupported = (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1);
    });
    return constraintsSupported;
}

@implementation UICollectionReusableView (AAPLGridLayout)

/**
 *  This is kind of a hack because cells don't have an intrinsic content size or
 *  any other way to constrain them to a size. As a result, labels that _should_
 *  wrap at the bounds of a cell, don't. So by temporarily adding constraints to
 *  the cell, we can make the labels wrap and the layout compute correctly.
 */
- (CGSize)aapl_preferredLayoutSizeFittingSize:(CGSize)fittingSize
{
    CGRect frame = self.frame;
    frame.size = fittingSize;
    self.frame = frame;

    CGSize size;

	if (collectionViewSupportsConstraints()) {
        size = [self systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
	} else {
        NSArray *constraints = @[
			[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationLessThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:fittingSize.width],
			[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationLessThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:UILayoutFittingExpandedSize.height]
		];

        [self addConstraints:constraints];
        [self updateConstraints];
        size = [self systemLayoutSizeFittingSize:fittingSize];
        [self removeConstraints:constraints];
    }

    frame.size = size;
    self.frame = frame;

    return size;
}

@end

@implementation UICollectionViewCell (AAPLGridLayout)

- (CGSize)aapl_preferredLayoutSizeFittingSize:(CGSize)fittingSize
{
    CGRect frame = self.frame;
    frame.size = fittingSize;
    self.frame = frame;

    CGSize size;

    if (collectionViewSupportsConstraints()) {
        [self layoutSubviews];
        size = [self.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
		[self setNeedsUpdateConstraints];
    } else {
        NSArray *constraints = @[
			[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationLessThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:fittingSize.width],
			[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationLessThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:UILayoutFittingExpandedSize.height]
		];

        [self addConstraints:constraints];
        [self updateConstraints];
        size = [self systemLayoutSizeFittingSize:fittingSize];
        [self removeConstraints:constraints];
    }

    // Only consider the height for cells, because the contentView isn't anchored correctly sometimes.
    fittingSize.height = size.height;
    frame.size = fittingSize;
    self.frame = frame;

    return fittingSize;
}

@end
