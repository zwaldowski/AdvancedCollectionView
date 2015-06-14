/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Subclasses of AAPLLayoutMetrics with specialisations for data sources.
 */

#import "AAPLDataSourceMetrics_Private.h"
#import "AAPLLayoutMetrics_Private.h"

@implementation AAPLDataSourceSupplementaryItem
@end

@implementation AAPLDataSourceSectionMetrics

+ (instancetype)metrics
{
    return [[self alloc] init];
}

+ (instancetype)defaultMetrics
{
    AAPLDataSourceSectionMetrics *metrics = [[self alloc] init];
    metrics.rowHeight = 44;
    metrics.numberOfColumns = 1;
    return metrics;
}

- (id)copyWithZone:(NSZone *)zone
{
    AAPLDataSourceSectionMetrics *copy = [super copyWithZone:zone];
    copy->_headers = [_headers copy];
    copy->_footers = [_footers copy];
    copy->_placeholder = [_placeholder copy];

    return copy;
}

- (AAPLSupplementaryItem *)newHeader
{
    AAPLDataSourceSupplementaryItem *header = [[AAPLDataSourceSupplementaryItem alloc] initWithElementKind:UICollectionElementKindSectionHeader];
    if (!_headers)
        _headers = @[header];
    else
        _headers = [_headers arrayByAddingObject:header];
    return header;
}

- (AAPLSupplementaryItem *)newFooter
{
    AAPLDataSourceSupplementaryItem *footer = [[AAPLDataSourceSupplementaryItem alloc] initWithElementKind:UICollectionElementKindSectionHeader];
    if (!_footers)
        _footers = @[footer];
    else
        _footers = [_footers arrayByAddingObject:footer];
    return footer;
}

- (void)applyValuesFromMetrics:(AAPLSectionMetrics *)metrics
{
    [super applyValuesFromMetrics:metrics];
    if (![metrics isKindOfClass:[AAPLDataSourceSectionMetrics class]])
        return;

    AAPLDataSourceSectionMetrics *dataSourceMetrics = (AAPLDataSourceSectionMetrics *)metrics;

    if (dataSourceMetrics.headers) {
        NSArray *headers = [NSArray arrayWithArray:self.headers];
        self.headers = [headers arrayByAddingObjectsFromArray:dataSourceMetrics.headers];
    }

    if (dataSourceMetrics.footers) {
        NSArray *footers = self.footers;
        self.footers = [dataSourceMetrics.footers arrayByAddingObjectsFromArray:footers];
    }

    if (!self.placeholder)
        self.placeholder = dataSourceMetrics.placeholder;
}


@end
