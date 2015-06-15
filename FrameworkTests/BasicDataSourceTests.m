/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Tests for the basic data source.
 */


@import UIKit;
@import XCTest;

#import "AAPLBasicDataSource.h"
#import "AAPLDataSource_Private.h"

@interface BasicDataSourceTests : XCTestCase
@end

@implementation BasicDataSourceTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testNumberOfHeadersInEmptyDataSource
{
    AAPLBasicDataSource *dataSource = [AAPLBasicDataSource new];

    XCTAssertEqual(0, [dataSource numberOfHeadersInSectionAtIndex:0 includeChildDataSouces:YES]);
}

- (void)testNumberOfHeadersInDataSourceWithGlobalHeaders
{
    AAPLBasicDataSource *dataSource = [AAPLBasicDataSource new];

    AAPLSupplementaryItem *firstHeader = [dataSource newHeaderForKey:@"FOO"];
    firstHeader.estimatedHeight = 100;

    XCTAssertEqual(1, [dataSource numberOfHeadersInSectionAtIndex:AAPLGlobalSectionIndex includeChildDataSouces:YES]);

    AAPLSupplementaryItem *secondHeader = [dataSource newHeaderForKey:@"Bar"];
    secondHeader.estimatedHeight = 100;
    XCTAssertEqual(2, [dataSource numberOfHeadersInSectionAtIndex:AAPLGlobalSectionIndex includeChildDataSouces:YES]);
}

- (void)testNumberOfHeadersInDefaultMetrics
{
    AAPLBasicDataSource *dataSource = [AAPLBasicDataSource new];

    AAPLSupplementaryItem *defaultHeader = [dataSource newSectionHeader];
    defaultHeader.estimatedHeight = 100;

    XCTAssertEqual(1, [dataSource numberOfHeadersInSectionAtIndex:0 includeChildDataSouces:YES]);
}

- (void)testNumberOfHeadersInSection
{
    AAPLBasicDataSource *dataSource = [AAPLBasicDataSource new];

    AAPLSupplementaryItem *sectionHeader = [dataSource newHeaderForSectionAtIndex:0];
    sectionHeader.estimatedHeight = 100;

    XCTAssertEqual(1, [dataSource numberOfHeadersInSectionAtIndex:0 includeChildDataSouces:YES]);
}

- (void)testNumberOfHeadersInSectionWithDefaultHeaders
{
    AAPLBasicDataSource *dataSource = [AAPLBasicDataSource new];

    AAPLSupplementaryItem *defaultHeader = [dataSource newSectionHeader];
    defaultHeader.estimatedHeight = 100;

    AAPLSupplementaryItem *sectionHeader = [dataSource newHeaderForSectionAtIndex:0];
    sectionHeader.estimatedHeight = 100;

    XCTAssertEqual(2, [dataSource numberOfHeadersInSectionAtIndex:0 includeChildDataSouces:YES]);
}

@end
