/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Have a cat? Want to know more about it? This view controller will display the details and sightings for a given AAPLCat instance.
  
 */

#import "AAPLCatDetailViewController.h"
#import "AAPLCatDetailDataSource.h"
#import "AAPLCatDetailHeader.h"

@interface AAPLCatDetailViewController ()
@property (nonatomic, strong) AAPLCatDetailDataSource *detailDataSource;
@property (nonatomic, strong) id selectedDataSourceObserver;
@end

@implementation AAPLCatDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.detailDataSource = [self newDetailDataSource];

	__weak typeof(&*self) weakself = self;

	AAPLLayoutSupplementaryMetrics *globalHeader = [self.detailDataSource newHeaderForKey:@"globalHeader"];
    globalHeader.visibleWhileShowingPlaceholder = YES;
    globalHeader.height = 110;
    globalHeader.supplementaryViewClass = [AAPLCatDetailHeader class];
	[globalHeader configureWithBlock:^(AAPLCatDetailHeader *headerView, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
		headerView.bottomBorderColor = nil;
		[headerView configureWithCat:weakself.cat];
	}];

    self.collectionView.dataSource = self.detailDataSource;
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

@end
