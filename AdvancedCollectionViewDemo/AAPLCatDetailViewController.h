/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Have a cat? Want to know more about it? This view controller will display the details and sightings for a given AAPLCat instance.
  
*/

@import AdvancedCollectionView;

@class  AAPLCat;

@interface AAPLCatDetailViewController : AAPLCollectionViewController
@property (nonatomic, strong) AAPLCat *cat;
@end
