/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A category on UICollectionView for tracking visible supplementary views via a collaborating view controller.
 */

@import UIKit;

NS_ASSUME_NONNULL_BEGIN




@interface UICollectionView (VisibleHeaders)

/** Retrieve the view for a supplementary view of a given kind at the specified index path. This method requires the collection view's delegate adopt the AAPLCollectionViewSupplementaryViewTracking protocol and track supplementary view display notifications from the collection view. Fortunately, AAPLCollectionViewController does all this.
 @return The supplementary view or nil if no supplementary view matches.
 */
- (nullable UICollectionReusableView *)aapl_supplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

@end


/// A protocol for View Controllers that track the visible supplementary views of the collection view
@protocol AAPLCollectionViewSupplementaryViewTracking <NSObject>
/// The delegate method used to find a supplementary view that is visible.
- (nullable UICollectionReusableView *)collectionView:(UICollectionView *)collectionView visibleViewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;
@end




NS_ASSUME_NONNULL_END
