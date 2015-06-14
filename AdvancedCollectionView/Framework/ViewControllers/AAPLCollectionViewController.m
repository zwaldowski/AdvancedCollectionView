/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of UICollectionViewController that adds support for swipe to edit and drag reordering.
 */

@import UIKit;

#import "AAPLCollectionViewController.h"
#import "AAPLDataSource_Private.h"
#import "AAPLSwipeToEditController.h"
#import "AAPLCollectionViewLayout_Private.h"
#import "AAPLCollectionViewCell_Private.h"
#import "AAPLAction.h"
#import "AAPLLocalization.h"
#import "AAPLDataSourceMapping.h"

#import "UIView+Helpers.h"
#import "AAPLDebug.h"
#import "UICollectionView+SupplementaryViews.h"

#define UPDATE_DEBUGGING 0

#if UPDATE_DEBUGGING
#define UPDATE_LOG(FORMAT, ...) NSLog(@"%@ " FORMAT, NSStringFromSelector(_cmd), __VA_ARGS__)
#define UPDATE_TRACE(MESSAGE) NSLog(@"%@ " MESSAGE, NSStringFromSelector(_cmd))
#else
#define UPDATE_LOG(FORMAT, ...)
#define UPDATE_TRACE(MESSAGE)
#endif

typedef void (^AAPLBatchUpdatesHandler)(dispatch_block_t updates, dispatch_block_t completionHandler);

static inline BOOL AAPLTracksSupplementaryViews(UICollectionView *collectionView)
{
    static BOOL tracksSupplementaryViews = YES;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tracksSupplementaryViews = [collectionView respondsToSelector:@selector(supplementaryViewForElementKind:atIndexPath:)];
    });
    return tracksSupplementaryViews;
}

static void * const AAPLDataSourceContext = @"DataSourceContext";

@interface AAPLCollectionViewController () <UICollectionViewDelegate, AAPLDataSourceDelegate, AAPLCollectionViewSupplementaryViewTracking>
@property (nonatomic, strong) AAPLSwipeToEditController *swipeController;
@property (nonatomic, copy) dispatch_block_t updateCompletionHandler;
@property (nonatomic, strong) NSMutableIndexSet *reloadedSections;
@property (nonatomic, strong) NSMutableIndexSet *deletedSections;
@property (nonatomic, strong) NSMutableIndexSet *insertedSections;
@property (nonatomic) BOOL performingUpdates;
@property (nonatomic, strong) NSMutableDictionary *visibleSupplementaryViews;

// ContentInset handling for Keyboard
@property (nonatomic) BOOL assignedContentInsets;
@property (nonatomic) BOOL calculatedContentInsets;
@property (nonatomic) BOOL calculatedTabBarHiddenValue;
@property (nonatomic) BOOL calculatedNavigationBarHiddenValue;
@property (nonatomic) UIInterfaceOrientation orientationForCalculatedInsets;
@property (nonatomic) CGRect applicationFrameForCalculatedInsets;
@property (nonatomic) BOOL keyboardIsShowing;
@property (nonatomic) UIEdgeInsets contentInsetsBeforeShowingKeyboard;
@end

@implementation AAPLCollectionViewController
@synthesize contentInsets = _contentInsets;

- (void)dealloc
{
    if ([self isViewLoaded])
        [self.collectionView removeObserver:self forKeyPath:@"dataSource" context:AAPLDataSourceContext];
}

- (void)loadView
{
    [super loadView];
    //  We need to know when the data source changes on the collection view so we can become the delegate for any APPLDataSource subclasses.
    [self.collectionView addObserver:self forKeyPath:@"dataSource" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:AAPLDataSourceContext];
    _swipeController = [[AAPLSwipeToEditController alloc] initWithCollectionView:self.collectionView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = NO;
    UIEdgeInsets insets = self.contentInsets;
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    UICollectionView *collectionView = self.collectionView;

    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if ([dataSource isKindOfClass:[AAPLDataSource class]]) {
        UICollectionView *wrapper = [AAPLCollectionViewWrapper wrapperForCollectionView:collectionView mapping:nil];
        [dataSource registerReusableViewsWithCollectionView:wrapper];
        [dataSource setNeedsLoadContent];
    }

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(observeKeyboardWillShowNotification:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(observeKeyboardWillHideNotification:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.editing = NO;
    [_swipeController viewDidDisappear:animated];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [center removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)setCollectionView:(UICollectionView *)collectionView
{
    UICollectionView *oldCollectionView = self.collectionView;

    // Always call super, because we don't know EXACTLY what UICollectionViewController does in -setCollectionView:.
    [super setCollectionView:collectionView];

    [oldCollectionView removeObserver:self forKeyPath:@"dataSource" context:AAPLDataSourceContext];

    //  We need to know when the data source changes on the collection view so we can become the delegate for any APPLDataSource subclasses.
    [collectionView addObserver:self forKeyPath:@"dataSource" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:AAPLDataSourceContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    //  For change contexts that aren't the data source, pass them to super.
    if (AAPLDataSourceContext != context) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    UICollectionView *collectionView = object;
    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;

    if ([dataSource isKindOfClass:[AAPLDataSource class]]) {
        AAPLDataSource *aaplDataSource = (AAPLDataSource *)dataSource;
        if (!aaplDataSource.delegate)
            aaplDataSource.delegate = self;
    }
}

- (void)setEditing:(BOOL)editing
{
    if (_editing == editing)
        return;

    _editing = editing;

    AAPLCollectionViewLayout *layout = (AAPLCollectionViewLayout *)self.collectionView.collectionViewLayout;

    NSAssert([layout isKindOfClass:[AAPLCollectionViewLayout class]], @"Editing only supported when using a layout derived from AAPLCollectionViewLayout");

    if ([layout isKindOfClass:[AAPLCollectionViewLayout class]])
        layout.editing = editing;
    self.swipeController.editing = editing;
    [layout invalidateLayout];
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets
{
    _contentInsets = contentInsets;
    _calculatedContentInsets = NO;
    _assignedContentInsets = YES;

    // I hope this triggers the VCs -viewDidLayoutSubviews method, which is where view layout should occur.
    [self.view setNeedsLayout];
}

- (UIEdgeInsets)contentInsets
{
    if (_assignedContentInsets)
        return _contentInsets;

    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGRect bounds = [[UIScreen mainScreen] bounds];

    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    UITabBar *tabBar = self.tabBarController.tabBar;

    // If the content insets were calculated, and the orientation is the same, return calculated value
    if (_calculatedContentInsets && _orientationForCalculatedInsets == orientation && CGRectEqualToRect(bounds, _applicationFrameForCalculatedInsets) && navigationBar.hidden == _calculatedNavigationBarHiddenValue && tabBar.hidden == _calculatedTabBarHiddenValue)
        return _contentInsets;

    // grab our frame in window coordinates
    CGRect rect = [self.view convertRect:self.view.bounds toView:nil];

    // No value has been assigned, so we need to compute it
    UIApplication *application = [UIApplication sharedApplication];

    UIEdgeInsets insets = UIEdgeInsetsZero;

    if (!application.statusBarHidden) {
        // The status bar is WEIRD. It doesn't seem to adjust when rotated.
        CGFloat height = (UIInterfaceOrientationIsPortrait(orientation) ? CGRectGetHeight(application.statusBarFrame) : CGRectGetWidth(application.statusBarFrame));

        if (CGRectGetMinY(rect) < height)
            insets.top += 20;
    }

    // If the navigation bar ISN'T hidden, we'll set our top inset to the bottom of the navigation bar. This allows the system to position things correctly to account for the double height status bar.
    if (!navigationBar.hidden) {
        // During rotation, the navigation bar (and possibly tab bar) doesn't resize immediately. Force it to have it's new size.
        [navigationBar sizeToFit];
        CGRect frame = [navigationBar convertRect:navigationBar.bounds toView:nil];

        if (CGRectIntersectsRect(rect, frame))
            insets.top += CGRectGetMaxY(frame) - CGRectGetMinY(frame);
    }

    if (!tabBar.hidden) {
        // During rotation, the navigation bar (and possibly tab bar) doesn't resize immediately. Force it to have it's new size.
        [tabBar sizeToFit];
        CGRect frame = [tabBar convertRect:tabBar.bounds toView:nil];
        if (CGRectIntersectsRect(rect, frame))
            insets.bottom = CGRectGetHeight(frame);
    }

    _calculatedContentInsets = YES;
    _orientationForCalculatedInsets = orientation;
    _applicationFrameForCalculatedInsets = bounds;
    _calculatedTabBarHiddenValue = tabBar.hidden;
    _calculatedNavigationBarHiddenValue = navigationBar.hidden;
    _contentInsets = insets;

    return insets;
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    if (!_assignedContentInsets) {
        _orientationForCalculatedInsets = UIInterfaceOrientationUnknown;
        _applicationFrameForCalculatedInsets = CGRectZero;
    }
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    if (!_assignedContentInsets) {
        _orientationForCalculatedInsets = UIInterfaceOrientationUnknown;
        _applicationFrameForCalculatedInsets = CGRectZero;
    }
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    UIEdgeInsets insets = self.contentInsets;
    UIEdgeInsets oldInsets = self.collectionView.contentInset;

    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
    if (!UIEdgeInsetsEqualToEdgeInsets(insets, oldInsets))
        [self.collectionView.collectionViewLayout invalidateLayout];
}

#pragma mark - Swipe to delete support

- (void)swipeToDeleteCell:(AAPLCollectionViewCell *)sender
{
    UICollectionView *collectionView = self.collectionView;
    AAPLCollectionViewLayout *layout = (AAPLCollectionViewLayout *)collectionView.collectionViewLayout;
    if (![layout isKindOfClass:[AAPLCollectionViewLayout class]])
        return;

    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        return;

    // Tell the cell it will be deleted…
    [sender prepareForInteractiveRemoval];

    NSIndexPath *deleteIndexPath = [self.collectionView indexPathForCell:sender];
    [dataSource performUpdate:^{
        [dataSource removeItemAtIndexPath:deleteIndexPath];
    }];
}

- (void)didSelectActionFromCell:(UICollectionViewCell *)cell
{
    [_swipeController shutActionPaneForEditingCellAnimated:YES];
}

- (void)presentAlertSheetFromCell:(UICollectionViewCell *)cell
{
    UICollectionView *collectionView = self.collectionView;
    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        return;

    NSIndexPath *indexPath = [collectionView indexPathForCell:cell];
    if (!indexPath)
        return;

    NSArray *editActions = [dataSource primaryActionsForItemAtIndexPath:indexPath];
    if (!editActions.count)
        return;

    UIAlertController *controller = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    for (AAPLAction *action in editActions) {
        SEL selector = action.selector;
        UIAlertAction *alertAction = [UIAlertAction actionWithTitle:action.title style:action.destructive ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault handler:^(UIAlertAction *blockAlertAction) {
            [cell aapl_sendAction:selector];
            [_swipeController shutActionPaneForEditingCellAnimated:YES];
        }];
        [controller addAction:alertAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:AAPL_LOC_CANCEL_BUTTON style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        // nothing to do…
    }];
    [controller addAction:cancelAction];

    [self presentViewController:controller animated:YES completion:nil];
}

#pragma mark - UICollectionViewDelegate methods

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!_swipeController.idle)
        return NO;

    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        return YES;

    AAPLDataSource *sectionDataSource = [dataSource dataSourceForSectionAtIndex:indexPath.section];
    return sectionDataSource.allowsSelection;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.editing)
        return NO;

    AAPLDataSource *dataSource = (AAPLDataSource *)collectionView.dataSource;
    if (![dataSource isKindOfClass:[AAPLDataSource class]])
        return YES;

    AAPLDataSource *sectionDataSource = [dataSource dataSourceForSectionAtIndex:indexPath.section];
    return sectionDataSource.allowsSelection;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    // If the collectionView tracks the supplementary views for us, we don't have to.
    if (AAPLTracksSupplementaryViews(collectionView))
        return;

    NSMutableDictionary *visibleSupplementaryViews = self.visibleSupplementaryViews;
    if (!visibleSupplementaryViews)
        visibleSupplementaryViews = self.visibleSupplementaryViews = [NSMutableDictionary dictionary];

    NSMutableDictionary *supplementaryViews = visibleSupplementaryViews[elementKind];
    if (!supplementaryViews)
        supplementaryViews = visibleSupplementaryViews[elementKind] = [NSMutableDictionary dictionary];

    supplementaryViews[indexPath] = view;
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingSupplementaryView:(UICollectionReusableView *)view forElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    // If the collectionView tracks the supplementary views for us, we don't have to.
    if (AAPLTracksSupplementaryViews(collectionView))
        return;

    NSMutableDictionary *visibleSupplementaryViews = self.visibleSupplementaryViews;
    if (!visibleSupplementaryViews)
        visibleSupplementaryViews = self.visibleSupplementaryViews = [NSMutableDictionary dictionary];

    NSMutableDictionary *supplementaryViews = visibleSupplementaryViews[elementKind];
    if (!supplementaryViews)
        supplementaryViews = visibleSupplementaryViews[elementKind] = [NSMutableDictionary dictionary];

    [supplementaryViews removeObjectForKey:indexPath];
}

#pragma mark - AAPLCollectionViewSupplementaryViewTracking

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView visibleViewForSupplementaryElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    // If the collectionView tracks the supplementary views for us this method shouldn't be called, because -appl_supplementaryViewForElementKind:atIndexPath: will defer to the native method.
    if (AAPLTracksSupplementaryViews(collectionView))
        return nil;

    NSMutableDictionary *visibleSupplementaryViews = self.visibleSupplementaryViews;
    if (!visibleSupplementaryViews)
        visibleSupplementaryViews = self.visibleSupplementaryViews = [NSMutableDictionary dictionary];

    NSMutableDictionary *supplementaryViews = visibleSupplementaryViews[elementKind];
    if (!supplementaryViews)
        supplementaryViews = visibleSupplementaryViews[elementKind] = [NSMutableDictionary dictionary];

    UICollectionReusableView *view = supplementaryViews[indexPath];
    return view;
}

#pragma mark - AAPLDataSourceDelegate methods

#if UPDATE_DEBUGGING

- (NSString *)stringFromArrayOfIndexPaths:(NSArray *)indexPaths
{
    NSMutableString *result = [NSMutableString string];
    for (NSIndexPath *indexPath in indexPaths) {
        if ([result length])
            [result appendString:@", "];
        [result appendString:AAPLStringFromNSIndexPath(indexPath)];
    }
    return result;
}

#endif

- (void)performBatchUpdates:(void(^)())updates completion:(void(^)())completion
{
    NSAssert([NSThread isMainThread], @"You can only call -performBatchUpdates:completion: from the main thread.");

    // We're currently updating the collection view, so we can't call -performBatchUpdates:completion: on it.
    if (self.performingUpdates) {
        UPDATE_TRACE(@"  PERFORMING UPDATES IMMEDIATELY");

        // Chain the completion handler if one was given
        if (completion) {
            dispatch_block_t oldCompletion = self.updateCompletionHandler;
            self.updateCompletionHandler = ^{
                oldCompletion();
                completion();
            };
        }
        // Now immediately execute the new updates
        if (updates)
            updates();
        return;
    }

#if UPDATE_DEBUGGING
    static NSInteger updateNumber = 0;
#endif
    UPDATE_LOG(@"%ld: PERFORMING BATCH UPDATE", (long)++updateNumber);

    self.reloadedSections = [NSMutableIndexSet indexSet];
    self.deletedSections = [NSMutableIndexSet indexSet];
    self.insertedSections = [NSMutableIndexSet indexSet];

    __block dispatch_block_t completionHandler = nil;

    [self.collectionView performBatchUpdates:^{
        UPDATE_LOG(@"%ld:  BEGIN UPDATE", (long)updateNumber);
        self.performingUpdates = YES;
        self.updateCompletionHandler = completion;

        updates();

        // Perform delayed reloadSections calls
        NSMutableIndexSet *sectionsToReload = [[NSMutableIndexSet alloc] initWithIndexSet:self.reloadedSections];

        // UICollectionView doesn't like it if you reload a section that was either inserted or deleted. So before we can call -reloadSections: all sections that were inserted or deleted must be removed.
        [sectionsToReload removeIndexes:self.deletedSections];
        [sectionsToReload removeIndexes:self.insertedSections];

        [self.collectionView reloadSections:sectionsToReload];
        UPDATE_LOG(@"%ld:  RELOADED SECTIONS: %@", (long)updateNumber, AAPLStringFromNSIndexSet(sectionsToReload));

        UPDATE_LOG(@"%ld:  END UPDATE", (long)updateNumber);
        self.performingUpdates = NO;
        completionHandler = self.updateCompletionHandler;
        self.updateCompletionHandler = nil;
        self.reloadedSections = nil;
        self.deletedSections = nil;
        self.insertedSections = nil;
    } completion:^(BOOL complete){
        UPDATE_LOG(@"%ld:  BEGIN COMPLETION HANDLER", (long)updateNumber);
        if (completionHandler)
            completionHandler();
        UPDATE_LOG(@"%ld:  END COMPLETION HANDLER", (long)updateNumber);
    }];
}

- (void)dataSource:(AAPLDataSource *)dataSource didInsertItemsAtIndexPaths:(NSArray *)indexPaths
{
    UPDATE_LOG(@"INSERT ITEMS: %@", [self stringFromArrayOfIndexPaths:indexPaths]);
    [self.collectionView insertItemsAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveItemsAtIndexPaths:(NSArray *)indexPaths
{
    NSIndexPath *trackedIndexPath = _swipeController.trackedIndexPath;
    if (trackedIndexPath) {
        for (NSIndexPath *indexPath in indexPaths) {
            if ([trackedIndexPath isEqual:indexPath]) {
                [_swipeController shutActionPaneForEditingCellAnimated:NO];
                break;
            }
        }
    }

    UPDATE_LOG(@"REMOVE ITEMS: %@", [self stringFromArrayOfIndexPaths:indexPaths]);

    [self.collectionView deleteItemsAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshItemsAtIndexPaths:(NSArray *)indexPaths
{
    UPDATE_LOG(@"REFRESH ITEMS: %@", [self stringFromArrayOfIndexPaths:indexPaths]);
    [self.collectionView reloadItemsAtIndexPaths:indexPaths];
}

- (void)dataSource:(AAPLDataSource *)dataSource didInsertSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    if (!sections)  // bail if nil just to keep collection view safe and pure
        return;
    UPDATE_LOG(@"INSERT SECTIONS: %@", AAPLStringFromNSIndexSet(sections));
    AAPLCollectionViewLayout *layout = (AAPLCollectionViewLayout *)self.collectionView.collectionViewLayout;
    if ([layout isKindOfClass:[AAPLCollectionViewLayout class]])
        [layout dataSource:dataSource didInsertSections:sections direction:direction];
    [self.collectionView insertSections:sections];
    [self.insertedSections addIndexes:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRemoveSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction
{
    if (!sections)  // bail if nil just to keep collection view safe and pure
        return;

    NSIndexPath *trackedIndexPath = _swipeController.trackedIndexPath;
    if (trackedIndexPath) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger sectionIndex, BOOL *stop) {
            if (trackedIndexPath.section  == (NSInteger)sectionIndex) {
                [self.swipeController shutActionPaneForEditingCellAnimated:NO];
                *stop = YES;
            }
        }];
    }

    UPDATE_LOG(@"DELETE SECTIONS: %@", AAPLStringFromNSIndexSet(sections));
    AAPLCollectionViewLayout *layout = (AAPLCollectionViewLayout *)self.collectionView.collectionViewLayout;
    if ([layout isKindOfClass:[AAPLCollectionViewLayout class]])
        [layout dataSource:dataSource didRemoveSections:sections direction:direction];
    [self.collectionView deleteSections:sections];
    // record the sections that were deleted
    [self.deletedSections addIndexes:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveSection:(NSInteger)section toSection:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction
{
    UPDATE_LOG(@"MOVE SECTION: %ld TO: %ld", (long)section, (long)newSection);
    AAPLCollectionViewLayout *layout = (AAPLCollectionViewLayout *)self.collectionView.collectionViewLayout;
    if ([layout isKindOfClass:[AAPLCollectionViewLayout class]])
        [layout dataSource:dataSource didMoveSection:section toSection:newSection direction:direction];
    [self.collectionView moveSection:section toSection:newSection];
}

- (void)dataSource:(AAPLDataSource *)dataSource didMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    UPDATE_LOG(@"MOVE ITEM: %@ TO: %@", AAPLStringFromNSIndexPath(indexPath), AAPLStringFromNSIndexPath(newIndexPath));
    [self.collectionView moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
}

- (void)dataSource:(AAPLDataSource *)dataSource didRefreshSections:(NSIndexSet *)sections
{
    if (!sections)  // bail if nil just to keep collection view safe and pure
        return;
    UPDATE_LOG(@"REFRESH SECTIONS: %@", AAPLStringFromNSIndexSet(sections));
    // It's not "legal" to reload a section if you also delete the section later in the same batch update. So we'll just remember that we want to reload these sections when we're performing a batch update and reload them only if they weren't also deleted.
    if (self.performingUpdates)
        [self.reloadedSections addIndexes:sections];
    else
        [self.collectionView reloadSections:sections];
}

- (void)dataSourceDidReloadData:(AAPLDataSource *)dataSource
{
    UPDATE_TRACE(@"RELOAD");
    [self.collectionView reloadData];
}

- (void)dataSource:(AAPLDataSource *)dataSource performBatchUpdate:(dispatch_block_t)update complete:(dispatch_block_t)complete
{
    [self performBatchUpdates:^{
        update();
    } completion:^{
        if (complete) {
            complete();
        }
    }];
}

- (void)dataSource:(AAPLDataSource *)dataSource didDismissPlaceholderForSections:(NSIndexSet *)sections
{
    UPDATE_LOG(@"Dismiss placeholder: sections=%@", AAPLStringFromNSIndexSet(sections));
    [self.reloadedSections addIndexes:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didPresentActivityIndicatorForSections:(NSIndexSet *)sections
{
    UPDATE_LOG(@"Present activity indicator: sections=%@", AAPLStringFromNSIndexSet(sections));
    [self.reloadedSections addIndexes:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didPresentPlaceholderForSections:(NSIndexSet *)sections
{
    UPDATE_LOG(@"Present placeholder: sections=%@", AAPLStringFromNSIndexSet(sections));
    [self.reloadedSections addIndexes:sections];
}

- (void)dataSource:(AAPLDataSource *)dataSource didUpdateSupplementaryItem:(AAPLSupplementaryItem *)supplementaryItem atIndexPaths:(NSArray *)supplementaryIndexPaths header:(BOOL)header
{
    UICollectionView *collectionView = self.collectionView;
    NSString *kind = header ? UICollectionElementKindSectionHeader : UICollectionElementKindSectionFooter;

    [self performBatchUpdates:^{
        AAPLCollectionViewLayoutInvalidationContext *context = [[[[collectionView.collectionViewLayout class] invalidationContextClass] alloc] init];

        for (NSIndexPath *indexPath in supplementaryIndexPaths) {
            AAPLDataSource *localDataSource = [dataSource dataSourceForSectionAtIndex:indexPath.section];
            UICollectionReusableView *view = [self collectionView:collectionView visibleViewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
            NSIndexPath *localIndexPath = [dataSource localIndexPathForGlobalIndexPath:indexPath];
            supplementaryItem.configureView(view, localDataSource, localIndexPath);
        }

        [context invalidateSupplementaryElementsOfKind:kind atIndexPaths:supplementaryIndexPaths];
    } completion:nil];
}

#pragma mark - Keyboard Notifications

- (void)observeKeyboardWillShowNotification:(NSNotification *)note
{
    CGFloat animationDuration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];
    CGRect keyboardRect = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];

    if (_keyboardIsShowing)
        return;

    // The keyboard rect is WRONG for landscape
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        keyboardRect.origin = CGPointMake(keyboardRect.origin.y, keyboardRect.origin.x);
        keyboardRect.size = CGSizeMake(keyboardRect.size.height, keyboardRect.size.width);
    }

    _keyboardIsShowing = YES;

    UIEdgeInsets insets = self.contentInsets;
    // Remember the previous contentInsets
    _contentInsetsBeforeShowingKeyboard = insets;

    UIView *view = self.view;
    CGRect rect = [view convertRect:view.frame toView:nil];

    // If the keyboard doesn't insersect the view's frame, then there's no need to adjust anything
    if (!CGRectIntersectsRect(keyboardRect, rect))
        return;

    // Jam the height of the keyboard as the bottom content inset
    insets.bottom = keyboardRect.size.height;
    // update the content insets, without flipping the assigned toggle.
    _contentInsets = insets;

    // Trigger a call to -viewWillLayoutSubviews inside the animation block
    [self.view setNeedsLayout];
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)observeKeyboardWillHideNotification:(NSNotification *)note
{
    CGFloat animationDuration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];

    if (!_keyboardIsShowing)
        return;
    
    _contentInsets = _contentInsetsBeforeShowingKeyboard;
    
    _keyboardIsShowing = NO;
    
    // Trigger a call to -viewWillLayoutSubviews inside the animation block
    [self.view setNeedsLayout];
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

@end
