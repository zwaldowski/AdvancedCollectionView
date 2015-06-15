/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The header view shown in the cat detail screen. This view shows the name of the cat, its conservation status, and the favorite flag.
 */

@import AdvancedCollectionView;

@class AAPLCat;

@interface AAPLCatDetailHeader : AAPLPinnableHeaderView

- (void)configureWithCat:(AAPLCat *)cat;

@end
