/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of AAPLDataSource with multiple child data sources. Child data sources may have multiple sections. Load content messages will be sent to all child data sources.
  
 */

#import "AAPLDataSource.h"

/// A data source that is composed of other data sources.
@interface AAPLComposedDataSource : AAPLDataSource

/// Add a data source to the data source.
- (void)addDataSource:(AAPLDataSource *)dataSource;

/// Remove the specified data source from this data source.
- (void)removeDataSource:(AAPLDataSource *)dataSource;

@end
