/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Common methods for adding headers to a data source. These methods all create AAPLSectionHeaderView headers.
  
 */

#import "AAPLDataSource+Headers.h"
#import "AAPLSectionHeaderView.h"

static NSString *AAPLDataSourceTitleHeaderKey = @"AAPLDataSourceTitleHeaderKey";

@implementation AAPLDataSource (Headers)

- (AAPLLayoutSupplementaryMetrics *)dataSourceTitleHeader
{
    AAPLLayoutSupplementaryMetrics *header = [self headerForKey:AAPLDataSourceTitleHeaderKey];
    if (header)
        return header;

    header = [self newHeaderForKey:AAPLDataSourceTitleHeaderKey];
    header.supplementaryViewClass = [AAPLSectionHeaderView class];
    header.configureView = ^(UICollectionReusableView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        AAPLSectionHeaderView *headerView = (AAPLSectionHeaderView *)view;
        headerView.leftText = dataSource.title;
    };

    return header;
}

- (AAPLLayoutSupplementaryMetrics *)dataSourceHeaderWithTitle:(NSString *)title
{
    AAPLLayoutSupplementaryMetrics *header = [self headerForKey:AAPLDataSourceTitleHeaderKey];
    if (header)
        return header;

    header = [self newHeaderForKey:AAPLDataSourceTitleHeaderKey];
    header.supplementaryViewClass = [AAPLSectionHeaderView class];
    header.configureView = ^(UICollectionReusableView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        AAPLSectionHeaderView *headerView = (AAPLSectionHeaderView *)view;
        headerView.leftText = title;
    };

    return header;
}

- (AAPLLayoutSupplementaryMetrics *)sectionHeaderForSectionAtIndex:(NSInteger)sectionIndex
{
    AAPLLayoutSupplementaryMetrics *newHeader = [self newHeaderForSectionAtIndex:sectionIndex];
    newHeader.supplementaryViewClass = [AAPLSectionHeaderView class];
    return newHeader;
}

- (AAPLLayoutSupplementaryMetrics *)sectionHeaderWithTitle:(NSString *)title forSectionAtIndex:(NSInteger)sectionIndex
{
    AAPLLayoutSupplementaryMetrics *newHeader = [self sectionHeaderForSectionAtIndex:sectionIndex];
    newHeader.configureView = ^(UICollectionReusableView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        AAPLSectionHeaderView *headerView = (AAPLSectionHeaderView *)view;
        headerView.leftText = title;
    };

    return newHeader;
}

@end
