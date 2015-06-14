/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Subclasses of AAPLLayoutMetrics with specialisations for data sources.
 
  These classes are used internally by AAPLDataSource to track metrics information.
 */

#import "AAPLLayoutMetrics.h"

NS_ASSUME_NONNULL_BEGIN




/// A subclass of AAPLSupplementaryItem used by data sources for customisation of headers & footers. Not for general use.
@interface AAPLDataSourceSupplementaryItem : AAPLSupplementaryItem
@end

/// A subclass of AAPLSectionMetrics used by data sources to keep track of headers and footers. Not for general use.
@interface AAPLDataSourceSectionMetrics : AAPLSectionMetrics

/// Create a new header associated with a specific data source
- (AAPLSupplementaryItem *)newHeader;

/// Create a new footer associated with a specific data source.
- (AAPLSupplementaryItem *)newFooter;

/// Create a metrics instance
+ (instancetype)metrics;

/// Create a default metrics instance
+ (instancetype)defaultMetrics;

@end




NS_ASSUME_NONNULL_END
