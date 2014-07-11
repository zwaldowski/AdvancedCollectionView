/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLLayoutMetrics.h"

@interface AAPLLayoutSupplementaryMetrics ()

/// A block that can be used to configure the supplementary view after it is created.
@property (nonatomic, copy) AAPLLayoutSupplementaryItemConfigurationBlock configureView;

@end

@interface AAPLLayoutSectionMetrics ()
@property (nonatomic) BOOL hasPlaceholder;
@property (nonatomic, strong) NSArray *headers;
@property (nonatomic, strong) NSArray *footers;
@end
