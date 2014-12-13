/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A basic data source that either fetches the list of all available cats or the user's favorite cats. If this data source represents the favorites, it listens for a notification with the name AAPLCatFavoriteToggledNotificationName and will update itself appropriately.
  
 */

#import "AAPLCatListDataSource.h"
#import "AAPLCat.h"

#import "AAPLDataAccessManager.h"

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
    [collectionView registerClass:[AAPLBasicCell class] forCellWithReuseIdentifier:NSStringFromClass([AAPLBasicCell class])];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLCat *cat = [self itemAtIndexPath:indexPath];
    AAPLBasicCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([AAPLBasicCell class]) forIndexPath:indexPath];
    cell.style = AAPLBasicCellStyleSubtitle;
    cell.primaryLabel.text = cat.name;
    cell.primaryLabel.font = [UIFont systemFontOfSize:14];
    cell.secondaryLabel.text = cat.shortDescription;
    cell.secondaryLabel.font = [UIFont systemFontOfSize:10];

    if (self.showingFavorites)
        cell.editActions = @[[AAPLAction destructiveActionWithTitle:NSLocalizedString(@"Delete", @"Delete") selector:@selector(swipeToDeleteCell:)]];

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

        self.items = items;
    });
}

- (void)loadContent
{
    [self loadContentWithBlock:^(AAPLLoading *loading) {
        void (^handler)(NSArray *cats, NSError *error) = ^(NSArray *cats, NSError *error) {
            // Check to make certain a more recent call to load content hasn't superceded this one…
            if (!loading.current) {
                [loading ignore];
                return;
            }

            if (error) {
                [loading doneWithError:error];
                return;
            }

            if (cats.count)
                [loading updateWithContent:^(AAPLCatListDataSource *me) {
                    me.items = cats;
                }];
            else
                [loading updateWithNoContent:^(AAPLCatListDataSource *me) {
                    me.items = @[];
                }];
        };

        if (self.showingFavorites)
            [[AAPLDataAccessManager manager] fetchFavoriteCatListWithCompletionHandler:handler];
        else
            [[AAPLDataAccessManager manager] fetchCatListWithCompletionHandler:handler];
    }];
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

@end
