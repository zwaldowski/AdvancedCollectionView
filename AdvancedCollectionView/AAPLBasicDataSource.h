/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of AAPLDataSource which permits only one section but manages its items in an NSArray. This class will perform all the necessary updates to animate changes to the array of items if they are updated using -setItems:animated:.
  
 */

#import "AAPLDataSource.h"

/// A subclass of ITCDataSource that manages a single section of items backed by an NSArray.
@interface AAPLBasicDataSource : AAPLDataSource

/// The items represented by this data source. This property is KVC compliant for mutable changes via -mutableArrayValueForKey:.
@property (nonatomic, copy) NSArray *items;

/// Set the items with optional animation. By default, setting the items is not animated.
- (void)setItems:(NSArray *)items animated:(BOOL)animated;

@end
