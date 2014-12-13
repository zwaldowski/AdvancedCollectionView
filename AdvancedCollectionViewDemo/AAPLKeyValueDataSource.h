/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A data source that populates its cells based on key/value information from a source object. The items in the data source are NSDictionary instances with the keys @"label" and @"keyPath". Any items for which the object does not have a value will not be displayed.
  
 */

@import AdvancedCollectionView;

@interface AAPLKeyValueDataSource : AAPLBasicDataSource

- (instancetype)initWithObject:(id)object NS_DESIGNATED_INITIALIZER;

@end
