/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Classes used to define the layout metrics.
  
  In general, it is preferable to add and remover headers and footers via the methods in the public API.
  
 */

#import "AAPLLayoutMetrics.h"

@interface AAPLLayoutSupplementaryMetrics ()
@end

@interface AAPLLayoutSectionMetrics ()
@property (nonatomic) BOOL hasPlaceholder;
@property (nonatomic, strong) NSArray *headers;
@property (nonatomic, strong) NSArray *footers;
@end
