/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A category on UICollectionView for tracking visible supplementary views via a collaborating view controller.
 */

#import "UICollectionView+SupplementaryViews.h"

@implementation UICollectionView (SupplementaryViews)

- (UICollectionReusableView *)aapl_supplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    static BOOL useNative = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        useNative = [self respondsToSelector:@selector(supplementaryViewForElementKind:atIndexPath:)];
    });

    if (useNative)
        return [self supplementaryViewForElementKind:kind atIndexPath:indexPath];

    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(collectionView:visibleViewForSupplementaryElementOfKind:atIndexPath:)])
        return [delegate collectionView:self visibleViewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
    else
        return nil;
}

@end
