/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLGridLayoutSeparatorView.h"
#import "AAPLCollectionViewGridLayoutAttributes.h"

@implementation AAPLGridLayoutSeparatorView

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
	if ([layoutAttributes isKindOfClass:AAPLCollectionViewGridLayoutAttributes.class]) {
		self.backgroundColor = ((AAPLCollectionViewGridLayoutAttributes *)layoutAttributes).backgroundColor;
	} else {
		self.backgroundColor = nil;
	}
}

@end
