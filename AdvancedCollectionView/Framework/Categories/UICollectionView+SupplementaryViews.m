/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A category on UICollectionView for tracking visible supplementary views via a collaborating view controller.
 */

#import "UICollectionView+SupplementaryViews.h"

@interface UICollectionView ()
- (UICollectionReusableView *)supplementaryViewForElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(9_0);
@end

BOOL AAPLCollectionViewTracksSupplements(void) {
    static BOOL tracksSupplementaryViews = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tracksSupplementaryViews = [UICollectionView instancesRespondToSelector:@selector(supplementaryViewForElementKind:atIndexPath:)];
    });
    return tracksSupplementaryViews;
}

@implementation UICollectionView (SupplementaryViews)

- (UICollectionReusableView *)aapl_supplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (AAPLCollectionViewTracksSupplements()) {
        return [self supplementaryViewForElementKind:kind atIndexPath:indexPath];
    }

    id delegate = self.delegate;
    if ([delegate conformsToProtocol:@protocol(AAPLCollectionViewSupplementaryViewTracking)]) {
        return [delegate collectionView:self visibleViewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
    } else {
        return nil;
    }
}

@end
