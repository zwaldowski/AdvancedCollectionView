/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Classes used to define the layout metrics.
 
  In general, it is preferable to add and remover headers and footers via the methods in the public API.
 */

#import "AAPLLayoutMetrics.h"

@interface AAPLSupplementaryItem ()
/// Returns YES if the supplementary layout metrics has estimated height
@property (nonatomic, readonly) BOOL hasEstimatedHeight;
/// Either the height or the estimatedHeight
@property (nonatomic, readonly) CGFloat fixedHeight;

- (instancetype)initWithElementKind:(NSString *)elementKind NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
@end

@interface AAPLSectionMetrics ()
@end
