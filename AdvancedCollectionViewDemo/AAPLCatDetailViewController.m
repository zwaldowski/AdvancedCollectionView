/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Have a cat? Want to know more about it? This view controller will display the details and sightings for a given AAPLCat instance.
  
 */

#import "AAPLCatDetailViewController.h"
#import "AAPLCatDetailDataSource.h"
#import "AAPLCatSightingsDataSource.h"

#import "AAPLCatDetailHeader.h"
#import "AAPLCat.h"

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

    AAPLLayoutSupplementaryMetrics *globalHeader = [self.dataSource newHeaderForKey:@"globalHeader"];
    globalHeader.visibleWhileShowingPlaceholder = YES;
    globalHeader.height = 110;
    globalHeader.supplementaryViewClass = [AAPLCatDetailHeader class];
    [globalHeader configureWithBlock:^(UICollectionReusableView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        AAPLCatDetailHeader *headerView = (AAPLCatDetailHeader *)view;
        headerView.bottomBorderColor = nil;
        [headerView configureWithCat:weakself.cat];
    }];

    self.collectionView.dataSource = self.dataSource;
}

- (AAPLCatDetailDataSource *)newDetailDataSource
{
    AAPLCatDetailDataSource *dataSource = [[AAPLCatDetailDataSource alloc] initWithCat:self.cat];
    dataSource.title = NSLocalizedString(@"Details", @"Title of cat details section");

    dataSource.noContentTitle = NSLocalizedString(@"No Cat", @"The title of the placeholder to show if the cat has no data");
    dataSource.noContentMessage = NSLocalizedString(@"This cat has no information.", @"The message to show when the cat has no information");
    
    dataSource.errorTitle = NSLocalizedString(@"Unable to Load", @"Error message title to show when unable to load cat details");

    NSString *errorMessage = NSLocalizedString(@"A network problem occurred loading details for “%@”.", @"Error message to show when unable to load cat details.");
    dataSource.errorMessage = [NSString localizedStringWithFormat:errorMessage, self.cat.name];


    return dataSource;
}

- (AAPLCatSightingsDataSource *)newSightingsDataSource
{
    AAPLCatSightingsDataSource *dataSource = [[AAPLCatSightingsDataSource alloc] initWithCat:self.cat];
    dataSource.title = NSLocalizedString(@"Sightings", @"Title of cat sightings section");
    dataSource.noContentTitle = NSLocalizedString(@"No Sightings", @"Title of the no sightings placeholder message");
    dataSource.noContentMessage = NSLocalizedString(@"This cat has not been sighted recently.", @"The message to show when the cat has not been sighted recently");

    dataSource.defaultMetrics.separatorColor = [UIColor colorWithWhite:0.88f alpha:1];
    dataSource.defaultMetrics.separatorInsets = UIEdgeInsetsMake(0, 15, 0, 0);
    dataSource.defaultMetrics.rowHeight = AAPLRowHeightVariable;
    
    return dataSource;
}

@end
