/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A basic data source that either fetches the list of all available cats.
  
 */

@import AdvancedCollectionView;

@interface AAPLCatListDataSource : AAPLBasicDataSource
/// Is this list showing the cats in reverse order?
@property (nonatomic) BOOL reversed;
@end
