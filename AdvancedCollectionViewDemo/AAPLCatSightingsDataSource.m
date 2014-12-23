/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
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

- (void)loadContent
{
    [self loadContentWithBlock:^(AAPLLoading *loading) {
        [[AAPLDataAccessManager manager] fetchSightingsForCat:self.cat completionHandler:^(NSArray *sightings, NSError *error) {
            if (!loading.current) {
                [loading ignore];
                return;
            }

            if (error) {
                [loading updateWithError:error];
                return;
            }

            [loading updateWithContent:^(AAPLCatSightingsDataSource *me){
                me.items = sightings;
            }];
        }];
    }];
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];
    [collectionView registerClass:[AAPLCatSightingCell class] forCellWithReuseIdentifier:NSStringFromClass([AAPLCatSightingCell class])];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLCatSightingCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([AAPLCatSightingCell class]) forIndexPath:indexPath];
    AAPLCatSighting *catSighting = [self itemAtIndexPath:indexPath];

    [cell configureWithCatSighting:catSighting dateFormatter:self.dateFormatter];
    return cell;
}

@end
