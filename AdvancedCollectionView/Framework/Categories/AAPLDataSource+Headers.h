/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Common methods for adding headers to a data source. These methods all create AAPLSectionHeaderView headers.
 */

#import "AAPLDataSource.h"

NS_ASSUME_NONNULL_BEGIN




@interface AAPLDataSource (Headers)

/// A header representing the title of this data source. This uses `AAPLSectionHeaderView`.
@property (nonatomic, readonly, strong) AAPLSupplementaryItem *dataSourceTitleHeader;

/// A header for the data source with a specific title. Uses `AAPLSectionHeaderView`.
- (AAPLSupplementaryItem *)dataSourceHeaderWithTitle:(NSString *)title;

/// Create a standard `AAPLSectionHeaderView` header for the section, but without any configuration.
- (AAPLSupplementaryItem *)sectionHeaderForSectionAtIndex:(NSInteger)sectionIndex;

/// Create a header with a specific title for a single section. This uses `AAPLSectionHeaderView`.
- (AAPLSupplementaryItem *)sectionHeaderWithTitle:(NSString *)title forSectionAtIndex:(NSInteger)sectionIndex;

@end




NS_ASSUME_NONNULL_END
