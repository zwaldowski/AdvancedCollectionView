//
//  AAPLGridLayoutColorView.m
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/14/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#import "AAPLGridLayoutColorView.h"
#import "AAPLCollectionViewGridLayoutAttributes.h"

@implementation AAPLGridLayoutColorView

- (void)applyLayoutAttributes:(AAPLCollectionViewGridLayoutAttributes *)layoutAttributes
{
    if ([layoutAttributes isKindOfClass:AAPLCollectionViewGridLayoutAttributes.class]) {
        self.backgroundColor = layoutAttributes.backgroundColor;
    } else {
        self.backgroundColor = nil;
    }
}

@end
