/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A basic data source for the sightings of a particular cat. When initialised with a cat, this data source will fetch the cat sightings.
 */

#import "AAPLCatSightingsDataSource.h"
#import "AAPLDataAccessManager.h"

#import "AAPLCatSighting.h"
#import "AAPLCat.h"

#import "AAPLCatSightingCell.h"

@interface AAPLCatSightingsDataSource ()
@property (nonatomic, strong) AAPLCat *cat;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation AAPLCatSightingsDataSource

- (instancetype)init
{
    return [self initWithCat:nil];
}

- (instancetype)initWithCat:(AAPLCat *)cat
{
    self = [super init];
    if (!self)
        return nil;

    _cat = cat;
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.dateStyle = NSDateFormatterShortStyle;
    _dateFormatter.timeStyle = NSDateFormatterShortStyle;
    return self;
}

- (void)loadContentWithProgress:(AAPLLoadingProgress *)progress
{
    [[AAPLDataAccessManager manager] fetchSightingsForCat:self.cat completionHandler:^(NSArray *sightings, NSError *error) {
        if (progress.cancelled)
            return;

        if (error) {
            [progress doneWithError:error];
            return;
        }

        [progress updateWithContent:^(AAPLCatSightingsDataSource *me){
            me.items = sightings;
        }];
    }];
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];
    [collectionView registerClass:[AAPLCatSightingCell class] forCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLCatSightingCell)];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLCatSightingCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLCatSightingCell) forIndexPath:indexPath];
    AAPLCatSighting *catSighting = [self itemAtIndexPath:indexPath];

    [cell configureWithCatSighting:catSighting dateFormatter:self.dateFormatter];
    return cell;
}

@end
