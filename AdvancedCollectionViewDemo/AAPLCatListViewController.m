/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The view controller that presents the list of cats. This view controller enables switching between all available cats and favorite cats via a segmented control in the navigation bar.
  
 */

#import "AAPLCatListViewController.h"
#import "AAPLCatListDataSource.h"
#import "AAPLCatDetailViewController.h"

static void *AAPLCatListSelectedContext = &AAPLCatListSelectedContext;

@interface APPLCatListViewController ()
@property (nonatomic, strong) AAPLSegmentedDataSource *segmentedDataSource;
@property (nonatomic, strong) AAPLCatListDataSource *catsDataSource;
@property (nonatomic, strong) AAPLCatListDataSource *favoriteCatsDataSource;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, strong) id selectedDataSourceObserver;
@end

@implementation APPLCatListViewController

- (void)dealloc
{
    [self.segmentedDataSource removeObserver:self forKeyPath:NSStringFromSelector(@selector(selectedDataSource)) context:AAPLCatListSelectedContext];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.catsDataSource = [self newAllCatsDataSource];
    self.favoriteCatsDataSource = [self newFavoriteCatsDataSource];

    AAPLSegmentedDataSource *segmentedDataSource = [[AAPLSegmentedDataSource alloc] init];

    AAPLLayoutSectionMetrics *metrics = segmentedDataSource.defaultMetrics;
    metrics.rowHeight = 44;
    metrics.separatorColor = [UIColor colorWithWhite:0.88f alpha:1];
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

    [self.segmentedDataSource addObserver:self forKeyPath:NSStringFromSelector(@selector(selectedDataSource)) options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:AAPLCatListSelectedContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == AAPLCatListSelectedContext) {
        // The title of the selected data source should appear in the back button; so update the title of this view controller when the selected data source changes.
        AAPLDataSource *dataSource = [object selectedDataSource];
        self.title = dataSource.title;

        if ([dataSource isEqual:self.catsDataSource]) {
            [self setEditing:NO animated:YES];
            [self.navigationItem setRightBarButtonItems:nil animated:YES];
        } else {
            [self.navigationItem setRightBarButtonItems:@[
                [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(beginEditing)]
            ] animated:YES];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (AAPLCatListDataSource *)newAllCatsDataSource
{
    AAPLCatListDataSource *dataSource = [[AAPLCatListDataSource alloc] init];
    dataSource.showingFavorites = NO;

    dataSource.title = NSLocalizedString(@"All", @"Title for available cats list");
    dataSource.noContentMessage = NSLocalizedString(@"All the big cats are napping or roaming elsewhere. Please try again later.", @"The message to show when no cats are available");
    dataSource.noContentTitle = NSLocalizedString(@"No Cats", @"The title to show when no cats are available");
    dataSource.errorMessage = NSLocalizedString(@"A problem with the network prevented loading the available cats.\nPlease, check your network settings.", @"Message to show when unable to load cats");
    dataSource.errorTitle = NSLocalizedString(@"Unable To Load Cats", @"Title of message to show when unable to load cats");

    return dataSource;
}

- (AAPLCatListDataSource *)newFavoriteCatsDataSource
{
    AAPLCatListDataSource *dataSource = [[AAPLCatListDataSource alloc] init];
    dataSource.showingFavorites = YES;

    dataSource.title = NSLocalizedString(@"Favorites", @"Title for favorite cats list");
    dataSource.noContentMessage = NSLocalizedString(@"You have no favorite cats. Tap the star icon to add a cat to your list of favorites.", @"The message to show when no cats are available");
    dataSource.noContentTitle = NSLocalizedString(@"No Favorites", @"The title to show when no cats are available");
    dataSource.errorMessage = NSLocalizedString(@"A problem with the network prevented loading your favorite cats. Please check your network settings.", @"Message to show when unable to load favorite cats");
    dataSource.errorTitle = NSLocalizedString(@"Unable To Favorites", @"Title of message to show when unable to load favorites");

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
