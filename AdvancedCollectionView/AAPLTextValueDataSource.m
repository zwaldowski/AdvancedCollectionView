/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A data source that populates its cells based on key/value information from a source object. The items in the data source are NSDictionary instances with the keys @"label" and @"keyPath". Any items for which the object does not have a value will not be displayed.
  This is a tad more complex than AAPLKeyValueDataSource, because each item will be used to create a single item section. The value of the label will be used to create a section header.
  
 */

#import "AAPLTextValueDataSource.h"
#import "AAPLTextValueCell.h"
#import "AAPLSectionHeaderView.h"
#import "UICollectionView+Helpers.h"

static NSString * const AAPLTextValueDataSourceKeyPathKey = @"keyPath";
static NSString * const AAPLTextValueDataSourceLabelKey = @"label";

@interface AAPLTextValueDataSource ()
@property (nonatomic, strong) id object;
@end

@implementation AAPLTextValueDataSource

@synthesize items = _items;

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

    self.defaultMetrics.selectedBackgroundColor = nil;

    // Create a section header that will pull the text of the header from the label of the item.
    AAPLLayoutSupplementaryMetrics *header = [self.defaultMetrics newHeader];
    header.supplementaryViewClass = [AAPLSectionHeaderView class];
    header.configureView = ^(UICollectionReusableView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        AAPLSectionHeaderView *header = (AAPLSectionHeaderView *)view;
        AAPLTextValueDataSource *me = (AAPLTextValueDataSource *)dataSource;
        NSDictionary *dictionary = me.items[indexPath.section];
        header.leftText = dictionary[AAPLTextValueDataSourceLabelKey];
    };

    return self;
}

- (void)setObject:(id)object
{
    if (object == _object)
        return;
    _object = object;
    [self notifySectionsRefreshed:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.numberOfSections)]];
}

- (id)itemAtIndexPath:(NSIndexPath *)indexPath
{
    return _items[indexPath.section];
}

- (NSInteger)numberOfSections
{
    return [_items count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.obscuredByPlaceholder)
        return 0;

    NSDictionary *dictionary = _items[section];
    NSString *keyPath = dictionary[AAPLTextValueDataSourceKeyPathKey];
    NSString *value = [self.object valueForKeyPath:keyPath];

    if (value)
        return 1;
    else
        return 0;
}

- (void)setItems:(NSArray *)items
{
    NSInteger oldNumberOfSections = self.numberOfSections;
    _items = [items copy];

    NSInteger newNumberOfSections = [_items count];

    NSIndexSet *refreshedSet;
    NSIndexSet *removedSet;
    NSIndexSet *insertedSet;

    if (newNumberOfSections == oldNumberOfSections)
        refreshedSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newNumberOfSections)];
    else if (newNumberOfSections < oldNumberOfSections) {
        refreshedSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newNumberOfSections)];
        removedSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(newNumberOfSections, oldNumberOfSections - newNumberOfSections)];
    }
    else if (newNumberOfSections > oldNumberOfSections) {
        refreshedSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, oldNumberOfSections)];
        insertedSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(oldNumberOfSections, newNumberOfSections - oldNumberOfSections)];
    }

    if (refreshedSet)
        [self notifySectionsRefreshed:refreshedSet];
    if (insertedSet)
        [self notifySectionsInserted:insertedSet];
    if (removedSet)
        [self notifySectionsRemoved:removedSet];
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];
    [collectionView registerClass:[AAPLTextValueCell class] forCellWithReuseIdentifier:NSStringFromClass([AAPLTextValueCell class])];
}

- (CGSize)collectionView:(UICollectionView *)collectionView sizeFittingSize:(CGSize)size forItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLTextValueCell *cell = (AAPLTextValueCell *)[self collectionView:collectionView cellForItemAtIndexPath:indexPath];
    CGSize fittingSize = [cell aapl_preferredLayoutSizeFittingSize:size];
    [cell removeFromSuperview];
    return fittingSize;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLTextValueCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([AAPLTextValueCell class]) forIndexPath:indexPath];
    NSDictionary *dictionary = [self itemAtIndexPath:indexPath];

    NSString *value = [self.object valueForKeyPath:dictionary[AAPLTextValueDataSourceKeyPathKey]];

    [cell configureWithText:value];
    return cell;
}

@end
