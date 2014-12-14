/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Common methods for adding headers to a data source. These methods all create AAPLSectionHeaderView headers.
  
 */

#import "AAPLDataSource.h"

@interface AAPLDataSource (Headers)

/// A header for the data source with a specific title. Uses AAPLSectionHeaderView.
- (AAPLLayoutSupplementaryMetrics *)addDataSourceHeaderWithTitle:(NSString *)title;

/// Create a header with a specific title for a single section. This uses AAPLSectionHeaderView.
- (AAPLLayoutSupplementaryMetrics *)newSectionHeaderWithTitle:(NSString *)title forSectionAtIndex:(NSInteger)sectionIndex;

@end
