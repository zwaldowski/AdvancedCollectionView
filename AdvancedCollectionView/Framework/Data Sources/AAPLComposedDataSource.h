/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 */

#import "AAPLDataSource.h"

/// A data source that is composed of other data sources.
@interface AAPLComposedDataSource : AAPLDataSource

/// Add a data source to the data source.
- (void)addDataSource:(AAPLDataSource *)dataSource;

/// Remove the specified data source from this data source.
- (void)removeDataSource:(AAPLDataSource *)dataSource __unused;

@end
