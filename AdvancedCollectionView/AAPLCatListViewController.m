/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The view controller that presents the list of cats.
  
 */

#import "AAPLCatListViewController.h"
#import "AAPLCatListDataSource.h"
#import "AAPLCatDetailViewController.h"

@interface APPLCatListViewController ()
@property (nonatomic, strong) AAPLCatListDataSource *dataSource;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, strong) id selectedDataSourceObserver;
@end

@implementation APPLCatListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	AAPLCatListDataSource *dataSource = [self newAllCatsDataSource];
	
	AAPLLayoutSectionMetrics *metrics = dataSource.defaultMetrics;
	metrics.rowHeight = 44;
	metrics.separatorColor = [UIColor colorWithWhite:224/255.0 alpha:1];
	metrics.separatorInsets = UIEdgeInsetsMake(0, 15, 0, 0);
	
	self.dataSource = dataSource;
	self.collectionView.dataSource = dataSource;
	self.title = dataSource.title;
}

- (AAPLCatListDataSource *)newAllCatsDataSource
{
    AAPLCatListDataSource *dataSource = [[AAPLCatListDataSource alloc] init];

    dataSource.title = NSLocalizedString(@"All", @"Title for available cats list");
    dataSource.noContentMessage = NSLocalizedString(@"All the big cats are napping or roaming elsewhere. Please try again later.", @"The message to show when no cats are available");
    dataSource.noContentTitle = NSLocalizedString(@"No Cats", @"The title to show when no cats are available");
    dataSource.errorMessage = NSLocalizedString(@"A problem with the network prevented loading the available cats.\nPlease, check your network settings.", @"Message to show when unable to load cats");
    dataSource.errorTitle = NSLocalizedString(@"Unable To Load Cats", @"Title of message to show when unable to load cats");

    return dataSource;
}

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"detail"]) {
        AAPLCatDetailViewController *controller = segue.destinationViewController;
        controller.cat = [self.dataSource itemAtIndexPath:self.selectedIndexPath];
    }
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    self.selectedIndexPath = indexPath;
    [self performSegueWithIdentifier:@"detail" sender:self];
}

@end
