/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A data source that populates its cells based on key/value information from a source object. The items in the data source are NSDictionary instances with the keys @"label" and @"keyPath". Any items for which the object does not have a value will not be displayed.
  This is a tad more complex than AAPLKeyValueDataSource, because each item will be used to create a single item section. The value of the label will be used to create a section header.
  
 */

@import AdvancedCollectionView;

@interface AAPLTextValueDataSource : AAPLDataSource

- (instancetype)initWithObject:(id)object NS_DESIGNATED_INITIALIZER;

@property (nonatomic, copy) NSArray *items;

@end
