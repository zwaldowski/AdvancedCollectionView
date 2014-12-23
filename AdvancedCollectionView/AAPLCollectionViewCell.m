/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
 The base collection view cell used by the AAPLCollectionViewGridLayout code.
 
 */

#import "AAPLCollectionViewCell.h"
#import "AAPLCollectionViewGridLayout_Private.h"

@implementation AAPLCollectionViewCell

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    // We don't get background or selectedBackground views unless we create them!
    self.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    self.selectedBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];

    return self;
}


- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    self.hidden = layoutAttributes.hidden;
    if ([layoutAttributes isKindOfClass:[AAPLCollectionViewGridLayoutAttributes class]]) {
        AAPLCollectionViewGridLayoutAttributes *attributes = (AAPLCollectionViewGridLayoutAttributes *)layoutAttributes;
        self.backgroundView.backgroundColor = attributes.backgroundColor;
        self.selectedBackgroundView.backgroundColor = attributes.selectedBackgroundColor;
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];

    if (highlighted) {
        [self insertSubview:self.selectedBackgroundView aboveSubview:self.backgroundView];
        self.selectedBackgroundView.alpha = 1;
        self.selectedBackgroundView.hidden = NO;
    }
    else {
        self.selectedBackgroundView.hidden = YES;
    }
}

@end
