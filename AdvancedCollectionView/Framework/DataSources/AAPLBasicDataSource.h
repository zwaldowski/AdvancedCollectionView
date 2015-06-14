/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of AAPLDataSource which permits only one section but manages its items in an NSArray. This class will perform all the necessary updates to animate changes to the array of items if they are updated using -setItems:animated:.
 */

#import "AAPLDataSource.h"

NS_ASSUME_NONNULL_BEGIN




/// A subclass of AAPLDataSource that manages a single section of items backed by an NSArray.
@interface AAPLBasicDataSource <ItemType : id> : AAPLDataSource<ItemType>

/**
 The items represented by this data source. This property is KVC compliant for mutable changes via -mutableArrayValueForKey:.
 @note This property MUST ONLY be modified within a call to -performUpdate:complete: (or -performUpdate:).
 */
@property (nonatomic, copy) NSArray<ItemType> *items;

/**
 Set the items with optional animation. By default, setting the items is not animated.
 @note Like setting the items property, this method MUST ONLY be called from within the update block of a call to -performUpdate:complete:.
 */
- (void)setItems:(NSArray<ItemType> *)items animated:(BOOL)animated;

@end




NS_ASSUME_NONNULL_END
