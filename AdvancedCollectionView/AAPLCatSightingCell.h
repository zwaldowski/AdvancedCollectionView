/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of AAPLCollectionViewCell that displays an AAPLCatSighting instance.
 */

@import AdvancedCollectionView;

@class AAPLCatSighting;

@interface AAPLCatSightingCell : AAPLCollectionViewCell

- (void)configureWithCatSighting:(AAPLCatSighting *)catSighting dateFormatter:(NSDateFormatter *)dateFormatter;

@end
