/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
 */

@import UIKit;

#import "AAPLCollectionViewLayoutAttributes.h"

NS_ASSUME_NONNULL_BEGIN




/// A subclass of UICollectionViewLayoutInvalidationContext that adds invalidation for metrics
@interface AAPLCollectionViewLayoutInvalidationContext : UICollectionViewLayoutInvalidationContext
/// Any index paths that have been explicitly invalidated need to be remeasured.
@property (nonatomic) BOOL invalidateMetrics;
@end

/**
 A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
 */
@interface AAPLCollectionViewLayout : UICollectionViewLayout

/// Is the layout in editing mode? Default is NO.
@property (nonatomic, getter = isEditing) BOOL editing;

@end




NS_ASSUME_NONNULL_END
