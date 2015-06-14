/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A basic data source that either fetches the list of all available cats or the user's favorite cats. If this data source represents the favorites, it listens for a notification with the name AAPLCatFavoriteToggledNotificationName and will update itself appropriately.
 */

#import "AAPLCatListDataSource.h"
#import "AAPLCat.h"

#import "AAPLDataAccessManager.h"

#import "AAPLBasicCell.h"

#import "AAPLAction.h"
#import "AAPLCollectionViewController.h"

@interface AAPLCatListDataSource ()
@end

@implementation AAPLCatListDataSource

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AAPLCatFavoriteToggledNotificationName object:nil];
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];
    [collectionView registerClass:[AAPLBasicCell class] forCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLBasicCell)];
}

- (NSArray *)primaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.showingFavorites)
        return nil;

    return @[
             [AAPLAction destructiveActionWithTitle:NSLocalizedString(@"Delete", @"Delete") selector:@selector(swipeToDeleteCell:)],
             [AAPLAction actionWithTitle:NSLocalizedString(@"Tickle", @"Tickle") selector:@selector(tickleCell:)],
             [AAPLAction actionWithTitle:NSLocalizedString(@"Confuse", @"Confuse") selector:@selector(tickleCell:)],
             [AAPLAction actionWithTitle:NSLocalizedString(@"Feed", @"Feed") selector:@selector(tickleCell:)]
             ];
}

- (NSArray *)secondaryActionsForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.showingFavorites)
        return nil;

    return @[
             [AAPLAction actionWithTitle:NSLocalizedString(@"Pet", @"Pet") selector:@selector(tickleCell:)]
             ];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLCat *cat = [self itemAtIndexPath:indexPath];
    AAPLBasicCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLBasicCell) forIndexPath:indexPath];
    cell.style = AAPLBasicCellStyleSubtitle;
    cell.primaryLabel.text = cat.name;
    cell.primaryLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    cell.secondaryLabel.text = cat.shortDescription;
    cell.secondaryLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];

    return cell;
}

- (void)setShowingFavorites:(BOOL)showingFavorites
{
    if (showingFavorites == _showingFavorites)
        return;

    _showingFavorites = showingFavorites;
    [self resetContent];
    [self setNeedsLoadContent];

    if (showingFavorites)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeFavoriteToggledNotification:) name:AAPLCatFavoriteToggledNotificationName object:nil];
}

- (void)observeFavoriteToggledNotification:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AAPLCat *cat = notification.object;
        NSMutableArray *items = [self.items mutableCopy];
        NSUInteger position = [items indexOfObject:cat];

        if (cat.favorite) {
            if (NSNotFound == position)
                [items addObject:cat];
        }
        else {
            if (NSNotFound != position)
                [items removeObjectAtIndex:position];
        }

        [self performUpdate:^{
            self.items = items;
        }];
    });
}

- (void)loadContentWithProgress:(AAPLLoadingProgress *)progress
{
    void (^handler)(NSArray *cats, NSError *error) = ^(NSArray *cats, NSError *error) {
        // Check to make certain a more recent call to load content hasn't superceded this one…
        if (progress.cancelled)
            return;

        if (error) {
            [progress doneWithError:error];
            return;
        }

        if (cats.count)
            [progress updateWithContent:^(AAPLCatListDataSource *me) {
                me.items = cats;
            }];
        else
            [progress updateWithNoContent:^(AAPLCatListDataSource *me) {
                me.items = @[];
            }];
    };

    if (self.showingFavorites)
        [[AAPLDataAccessManager manager] fetchFavoriteCatListWithCompletionHandler:handler];
    else
        [[AAPLDataAccessManager manager] fetchCatListWithCompletionHandler:handler];
}

#pragma mark - Drag reorder support

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    return YES;
}

#pragma mark - BOGUS

// bogus declaration
- (void)tickleCell:(id)sender
{
}

@end
