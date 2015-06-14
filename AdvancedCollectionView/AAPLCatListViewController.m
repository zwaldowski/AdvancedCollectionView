/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The view controller that presents the list of cats. This view controller enables switching between all available cats and favorite cats via a segmented control in the navigation bar.
 */

@import UIKit;

#import "AAPLCatListViewController.h"
#import "AAPLCatListDataSource.h"
#import "AAPLSegmentedDataSource.h"
#import "AAPLCatDetailViewController.h"

static void * const AAPLCatListSelectedDataSourceContext = "AAPLCatListSelectedDataSourceContext";
static NSString * const AAPLSelectedDataSourceKeyPath = @"selectedDataSource";

@interface AAPLCatListViewController ()
@property (nonatomic, strong) AAPLSegmentedDataSource *segmentedDataSource;
@property (nonatomic, strong) AAPLCatListDataSource *catsDataSource;
@property (nonatomic, strong) AAPLCatListDataSource *favoriteCatsDataSource;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@end

@implementation AAPLCatListViewController

- (void)dealloc
{
    [_segmentedDataSource removeObserver:self forKeyPath:AAPLSelectedDataSourceKeyPath context:AAPLCatListSelectedDataSourceContext];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.catsDataSource = [self newAllCatsDataSource];
    self.favoriteCatsDataSource = [self newFavoriteCatsDataSource];

    AAPLSegmentedDataSource *segmentedDataSource = [[AAPLSegmentedDataSource alloc] init];

    AAPLSectionMetrics *metrics = segmentedDataSource.defaultMetrics;
    metrics.estimatedRowHeight = 44;
    metrics.showsRowSeparator = YES;
    metrics.separatorInsets = UIEdgeInsetsMake(0, 15, 0, 0);

    [segmentedDataSource addDataSource:self.catsDataSource];
    [segmentedDataSource addDataSource:self.favoriteCatsDataSource];

    self.segmentedDataSource = segmentedDataSource;

    self.collectionView.dataSource = segmentedDataSource;

    // Create a segmented control to place in the navigation bar and ask the segmented data source to manage it.
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[]];
    self.navigationItem.titleView = segmentedControl;
    segmentedDataSource.shouldDisplayDefaultHeader = NO;
    [segmentedDataSource configureSegmentedControl:segmentedControl];

    // The title of the selected data source should appear in the back button; observe the changing value of the selected data source.
    [self.segmentedDataSource addObserver:self forKeyPath:AAPLSelectedDataSourceKeyPath options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:AAPLCatListSelectedDataSourceContext];
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary *)change context:(nullable void *)context
{
    if (context != AAPLCatListSelectedDataSourceContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    AAPLDataSource *dataSource = self.segmentedDataSource.selectedDataSource;

    self.title = dataSource.title;

    if (dataSource == self.catsDataSource) {
        self.editing = NO;
        self.navigationItem.rightBarButtonItem = nil;
    }
    else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(beginEditing)];
    }
}

- (AAPLCatListDataSource *)newAllCatsDataSource
{
    AAPLCatListDataSource *dataSource = [[AAPLCatListDataSource alloc] init];
    dataSource.showingFavorites = NO;

    dataSource.title = NSLocalizedString(@"All", @"Title for available cats list");
    dataSource.noContentPlaceholder = [AAPLDataSourcePlaceholder placeholderWithTitle:NSLocalizedString(@"No Cats", @"The title to show when no cats are available") message:NSLocalizedString(@"All the big cats are napping or roaming elsewhere. Please try again later.", @"The message to show when no cats are available") image:nil];
    dataSource.errorPlaceholder = [AAPLDataSourcePlaceholder placeholderWithTitle:NSLocalizedString(@"Unable To Load Cats", @"Title of message to show when unable to load cats") message:NSLocalizedString(@"A problem with the network prevented loading the available cats.\nPlease, check your network settings.", @"Message to show when unable to load cats") image:nil];

    return dataSource;
}

- (AAPLCatListDataSource *)newFavoriteCatsDataSource
{
    AAPLCatListDataSource *dataSource = [[AAPLCatListDataSource alloc] init];
    dataSource.showingFavorites = YES;

    dataSource.title = NSLocalizedString(@"Favorites", @"Title for favorite cats list");
    dataSource.noContentPlaceholder = [AAPLDataSourcePlaceholder placeholderWithTitle:NSLocalizedString(@"No Favorites", @"The title to show when no cats are available") message:NSLocalizedString(@"You have no favorite cats. Tap the star icon to add a cat to your list of favorites.", @"The message to show when no cats are available") image:nil];
    dataSource.errorPlaceholder = [AAPLDataSourcePlaceholder placeholderWithTitle:NSLocalizedString(@"Unable To Favorites", @"Title of message to show when unable to load favorites") message:NSLocalizedString(@"A problem with the network prevented loading your favorite cats. Please check your network settings.", @"Message to show when unable to load favorite cats") image:nil];

    return dataSource;
}

#pragma mark - Actions

- (void)beginEditing
{
    self.editing = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(endEditing)];
}

- (void)endEditing
{
    self.editing = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(beginEditing)];
    // This is where we should update the server with the favorites…
}

- (void)tickleCell:(id)sender
{
    // do something…
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
