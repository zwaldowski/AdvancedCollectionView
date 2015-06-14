/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Have a cat? Want to know more about it? This view controller will display the details and sightings for a given AAPLCat instance.
 */

@import UIKit;

#import "AAPLCatDetailViewController.h"
#import "AAPLSegmentedDataSource.h"
#import "AAPLCatDetailDataSource.h"
#import "AAPLCatSightingsDataSource.h"

#import "AAPLCatDetailHeader.h"

@interface AAPLCatDetailViewController ()
@property (nonatomic, strong) AAPLSegmentedDataSource *dataSource;
@property (nonatomic, strong) AAPLCatDetailDataSource *detailDataSource;
@property (nonatomic, strong) AAPLCatSightingsDataSource *sightingsDataSource;
@property (nonatomic, strong) id selectedDataSourceObserver;
@end

@implementation AAPLCatDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.dataSource = [[AAPLSegmentedDataSource alloc] init];
    self.detailDataSource = [self newDetailDataSource];
    self.sightingsDataSource = [self newSightingsDataSource];

    [self.dataSource addDataSource:self.detailDataSource];
    [self.dataSource addDataSource:self.sightingsDataSource];

    __weak typeof(&*self) weakself = self;

    AAPLSupplementaryItem *globalHeader = [self.dataSource newHeaderForKey:@"globalHeader"];
    globalHeader.visibleWhileShowingPlaceholder = YES;
    globalHeader.estimatedHeight = 110;
    globalHeader.supplementaryViewClass = [AAPLCatDetailHeader class];
    globalHeader.configureView = ^(UICollectionReusableView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        AAPLCatDetailHeader *headerView = (AAPLCatDetailHeader *)view;
        [headerView configureWithCat:weakself.cat];
    };

    self.collectionView.dataSource = self.dataSource;
}

- (AAPLCatDetailDataSource *)newDetailDataSource
{
    AAPLCatDetailDataSource *dataSource = [[AAPLCatDetailDataSource alloc] initWithCat:self.cat];
    dataSource.title = NSLocalizedString(@"Details", @"Title of cat details section");

    dataSource.noContentPlaceholder = [AAPLDataSourcePlaceholder placeholderWithTitle:NSLocalizedString(@"No Cat", @"The title of the placeholder to show if the cat has no data") message:NSLocalizedString(@"This cat has no information.", @"The message to show when the cat has no information") image:nil];

#pragma diagnostic push
#pragma GCC diagnostic ignored "-Wformat-nonliteral"
    NSString *errorMessage = NSLocalizedString(@"A network problem occurred loading details for “%@”.", @"Error message to show when unable to load cat details.");
    dataSource.errorPlaceholder = [AAPLDataSourcePlaceholder placeholderWithTitle:NSLocalizedString(@"Unable to Load", @"Error message title to show when unable to load cat details") message:[NSString localizedStringWithFormat:errorMessage, self.cat.name] image:nil];
#pragma GCC diagnostic pop

    return dataSource;
}

- (AAPLCatSightingsDataSource *)newSightingsDataSource
{
    AAPLCatSightingsDataSource *dataSource = [[AAPLCatSightingsDataSource alloc] initWithCat:self.cat];
    dataSource.title = NSLocalizedString(@"Sightings", @"Title of cat sightings section");
    dataSource.noContentPlaceholder = [AAPLDataSourcePlaceholder placeholderWithTitle:NSLocalizedString(@"No Sightings", @"Title of the no sightings placeholder message") message:NSLocalizedString(@"This cat has not been sighted recently.", @"The message to show when the cat has not been sighted recently") image:nil];

    dataSource.defaultMetrics.showsRowSeparator = YES;
    dataSource.defaultMetrics.separatorInsets = UIEdgeInsetsMake(0, 15, 0, 0);
    dataSource.defaultMetrics.estimatedRowHeight = 60;

    return dataSource;
}

- (void)toggleFavorite:(id)sender
{
    self.cat.favorite = !self.cat.favorite;
}

@end
