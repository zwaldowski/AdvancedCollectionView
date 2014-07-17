/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLCollectionViewCell.h"
#import "AAPLCollectionViewGridLayoutAttributes.h"

@implementation AAPLCollectionViewCell

+ (BOOL)requiresConstraintBasedLayout
{
	return YES;
}

- (void)commonInit
{
	// We don't get background or selectedBackground views unless we create them!
	self.backgroundView = [[UIView alloc] init];
	self.selectedBackgroundView = [[UIView alloc] init];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	[self commonInit];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
	
	[self commonInit];

    return self;
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];

	if ([layoutAttributes isKindOfClass:AAPLCollectionViewGridLayoutAttributes.class]) {
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
