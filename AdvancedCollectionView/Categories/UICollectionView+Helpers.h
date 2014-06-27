/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A category of methods that makes working with reusable cells and supplementary views a bit easier.
  
 */

#import <UIKit/UIKit.h>

@interface UICollectionReusableView (GridLayout)
- (CGSize)aapl_preferredLayoutSizeFittingSize:(CGSize)targetSize;
@end
