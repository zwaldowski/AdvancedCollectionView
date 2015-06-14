/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Common methods for adding headers to a data source. These methods all create AAPLSectionHeaderView headers.
 */

#import "AAPLDataSource+Headers.h"
#import "AAPLSectionHeaderView.h"

static NSString *AAPLDataSourceTitleHeaderKey = @"AAPLDataSourceTitleHeaderKey";

@implementation AAPLDataSource (Headers)

- (AAPLSupplementaryItem *)dataSourceTitleHeader
{
    AAPLSupplementaryItem *header = [self headerForKey:AAPLDataSourceTitleHeaderKey];
    if (header)
        return header;

    header = [self newHeaderForKey:AAPLDataSourceTitleHeaderKey];
    header.supplementaryViewClass = [AAPLSectionHeaderView class];
    header.configureView = ^(AAPLSectionHeaderView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        view.leftText = dataSource.title;
    };

    return header;
}

- (AAPLSupplementaryItem *)dataSourceHeaderWithTitle:(NSString *)title
{
    AAPLSupplementaryItem *header = [self headerForKey:AAPLDataSourceTitleHeaderKey];
    if (header)
        return header;

    header = [self newHeaderForKey:AAPLDataSourceTitleHeaderKey];
    header.supplementaryViewClass = [AAPLSectionHeaderView class];
    header.configureView = ^(AAPLSectionHeaderView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        view.leftText = title;
    };

    return header;
}

- (AAPLSupplementaryItem *)sectionHeaderForSectionAtIndex:(NSInteger)sectionIndex
{
    AAPLSupplementaryItem *newHeader = [self newHeaderForSectionAtIndex:sectionIndex];
    newHeader.supplementaryViewClass = [AAPLSectionHeaderView class];
    return newHeader;
}

- (AAPLSupplementaryItem *)sectionHeaderWithTitle:(NSString *)title forSectionAtIndex:(NSInteger)sectionIndex
{
    AAPLSupplementaryItem *newHeader = [self sectionHeaderForSectionAtIndex:sectionIndex];
    newHeader.configureView = ^(AAPLSectionHeaderView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        view.leftText = title;
    };

    return newHeader;
}

@end
