/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Common methods for adding headers to a data source. These methods all create AAPLSectionHeaderView headers.
  
 */

#import "AAPLDataSource.h"

@interface AAPLDataSource (Headers)

/// A header that represents the title of this data source. This uses AAPLSectionHeaderView.
- (AAPLLayoutSupplementaryMetrics *)dataSourceTitleHeader;

/// A header for the data source with a specific title. Uses AAPLSectionHeaderView.
- (AAPLLayoutSupplementaryMetrics *)dataSourceHeaderWithTitle:(NSString *)title;

/// Create a standard AAPLSectionHeaderView header for the section, but without any configuration.
- (AAPLLayoutSupplementaryMetrics *)sectionHeaderForSectionAtIndex:(NSInteger)sectionIndex;

/// Create a header with a specific title for a single section. This uses AAPLSectionHeaderView.
- (AAPLLayoutSupplementaryMetrics *)sectionHeaderWithTitle:(NSString *)title forSectionAtIndex:(NSInteger)sectionIndex;

@end
