/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
 The view controller that presents the list of cats. This view controller enables switching between all available cats and the same list in reverse via a segmented control in the navigation bar.
 
 */

#import "AAPLCatListViewController.h"
#import "AAPLCatListDataSource.h"
#import "AAPLCatDetailViewController.h"

@interface APPLCatListViewController ()
@property (nonatomic, strong) AAPLSegmentedDataSource *segmentedDataSource;
@property (nonatomic, strong) AAPLCatListDataSource *catsDataSource;
@property (nonatomic, strong) AAPLCatListDataSource *reversedCatsDataSource;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@end

@implementation APPLCatListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.catsDataSource = [self newAllCatsDataSource:NO];
    self.reversedCatsDataSource = [self newAllCatsDataSource:YES];

    AAPLSegmentedDataSource *segmentedDataSource = [[AAPLSegmentedDataSource alloc] init];

    AAPLLayoutSectionMetrics *metrics = segmentedDataSource.defaultMetrics;
    metrics.rowHeight = 44;
    metrics.separatorColor = [UIColor colorWithWhite:0.88f alpha:1];
    metrics.separatorInsets = UIEdgeInsetsMake(0, 15, 0, 0);

    [segmentedDataSource addDataSource:self.catsDataSource];
    [segmentedDataSource addDataSource:self.reversedCatsDataSource];

    self.segmentedDataSource = segmentedDataSource;

    self.collectionView.dataSource = segmentedDataSource;

    // Create a segmented control to place in the navigation bar and ask the segmented data source to manage it.
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[]];
    self.navigationItem.titleView = segmentedControl;
    segmentedDataSource.shouldDisplayDefaultHeader = NO;
    [segmentedDataSource configureSegmentedControl:segmentedControl];
}

- (AAPLCatListDataSource *)newAllCatsDataSource:(BOOL)reversed
{
    AAPLCatListDataSource *dataSource = [[AAPLCatListDataSource alloc] init];
    dataSource.reversed = reversed;
    
    if (reversed) {
        dataSource.title = NSLocalizedString(@"Reversed", @"Title for reversed cats list");
    } else {
        dataSource.title = NSLocalizedString(@"All", @"Title for available cats list");
    }
    
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
        controller.cat = [self.segmentedDataSource itemAtIndexPath:self.selectedIndexPath];
    }
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    self.selectedIndexPath = indexPath;
    [self performSegueWithIdentifier:@"detail" sender:self];
}

@end
