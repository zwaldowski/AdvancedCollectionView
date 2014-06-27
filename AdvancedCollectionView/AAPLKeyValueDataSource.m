/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A data source that populates its cells based on key/value information from a source object. The items in the data source are NSDictionary instances with the keys @"label" and @"keyPath". Any items for which the object does not have a value will not be displayed.
  
 */

#import "AAPLKeyValueDataSource.h"
#import "AAPLBasicCell.h"

#import "UICollectionView+Helpers.h"


static NSString * const AAPLKeyValueDataSourceKeyPathKey = @"keyPath";
static NSString * const AAPLKeyValueDataSourceLabelKey = @"label";

@interface AAPLKeyValueDataSource ()
@property (nonatomic, strong) id object;
@end

@implementation AAPLKeyValueDataSource

- (instancetype)init
{
    return [self initWithObject:nil];
}

- (instancetype)initWithObject:(id)object
{
    self = [super init];
    if (!self)
        return nil;

    _object = object;
    return self;
}

- (void)setItems:(NSArray *)items
{
    // Filter out any items that don't have a value, because it looks sloppy when rows have a label but no value
    NSMutableArray *newItems = [NSMutableArray array];
    for (NSDictionary *dictionary in items) {
        id value = [self.object valueForKeyPath:dictionary[AAPLKeyValueDataSourceKeyPathKey]];
        if (value)
            [newItems addObject:dictionary];
    }
    [super setItems:newItems];
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];
    [collectionView registerClass:[AAPLBasicCell class] forCellWithReuseIdentifier:NSStringFromClass([AAPLBasicCell class])];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *dictionary = [self itemAtIndexPath:indexPath];
    AAPLBasicCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([AAPLBasicCell class]) forIndexPath:indexPath];

    cell.primaryLabel.text = dictionary[AAPLKeyValueDataSourceLabelKey];
    cell.secondaryLabel.text = [self.object valueForKeyPath:dictionary[AAPLKeyValueDataSourceKeyPathKey]];
    return cell;
}

@end
