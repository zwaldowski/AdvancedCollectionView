/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A data source that populates its cells based on key/value information from a source object. The items in the data source are NSDictionary instances with the keys @"label" and @"keyPath". Any items for which the object does not have a value will not be displayed.
  This is a tad more complex than AAPLKeyValueDataSource, because each item will be used to create a single item section. The value of the label will be used to create a section header.
 */

#import "AAPLTextValueDataSource.h"
#import "AAPLTextValueCell.h"
#import "AAPLSectionHeaderView.h"

@implementation AAPLTextValueDataSource


- (void)setItems:(NSArray *)items animated:(BOOL)animated
{
    // Before we call super, we need to check the type of the AAPLKeyValueItem instances we were passed
    for (AAPLKeyValueItem *keyValueItem in items) {
        NSAssert(AAPLKeyValueItemTypeDefault == keyValueItem.itemType, @"AAPLTextValueDataSource only supports default key value items");
    }

    [super setItems:items animated:animated];
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];
    [collectionView registerClass:[AAPLTextValueCell class] forCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLTextValueCell)];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLTextValueCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLTextValueCell) forIndexPath:indexPath];
    AAPLKeyValueItem *item = [self itemAtIndexPath:indexPath];
    NSString *value = [item valueForObject:self.object];

    [cell configureWithTitle:item.localizedTitle text:value];
    return cell;
}

@end
