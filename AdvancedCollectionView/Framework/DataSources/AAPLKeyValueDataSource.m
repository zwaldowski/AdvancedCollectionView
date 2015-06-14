/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A data source for presenting items represented by key paths on a single object.
 */

#import "AAPLKeyValueDataSource.h"
#import "AAPLKeyValueCell.h"

@interface AAPLKeyValueItem ()
@property (nonatomic, readwrite) AAPLKeyValueItemType itemType;
@end

@implementation AAPLKeyValueItem

+ (instancetype)buttonItemWithLocalizedTitle:(NSString *)title keyPath:(NSString *)keyPath transformer:(AAPLKeyValueTransformer)transformer imageTransformer:(AAPLKeyValueImageTransformer)imageTransformer action:(SEL)action
{
    AAPLKeyValueItem *item = [[self alloc] init];
    item.localizedTitle = title;
    item.keyPath = keyPath;
    item.transformer = transformer;
    item.imageTransformer = imageTransformer;
    item.itemType = AAPLKeyValueItemTypeButton;
    item.action = action;
    return item;
}

+ (instancetype)itemWithLocalizedTitle:(NSString *)title keyPath:(NSString *)keyPath transformer:(AAPLKeyValueTransformer)transformer
{
    AAPLKeyValueItem *item = [[self alloc] init];
    item.localizedTitle = title;
    item.keyPath = keyPath;
    item.transformer = transformer;
    return item;
}

+ (instancetype)URLWithLocalizedTitle:(NSString *)title keyPath:(NSString *)keyPath transformer:(AAPLKeyValueTransformer)transformer
{
    AAPLKeyValueItem *item = [[self alloc] init];
    item.localizedTitle = title;
    item.keyPath = keyPath;
    item.transformer = transformer;
    item.itemType = AAPLKeyValueItemTypeURL;
    return item;
}

+ (instancetype)itemWithLocalizedTitle:(NSString *)title transformer:(AAPLKeyValueTransformer)transformer
{
    return [self itemWithLocalizedTitle:title keyPath:nil transformer:transformer];
}

+ (instancetype)itemWithLocalizedTitle:(NSString *)title keyPath:(NSString *)keyPath
{
    return [self itemWithLocalizedTitle:title keyPath:keyPath transformer:nil];
}

+ (instancetype)URLWithLocalizedTitle:(NSString *)title keyPath:(NSString *)keyPath
{
    return [self URLWithLocalizedTitle:title keyPath:keyPath transformer:nil];
}

- (NSString *)valueForObject:(id)object
{
    id value = nil;
    if (self.keyPath)
        value = [object valueForKeyPath:self.keyPath];
    else
        value = object;
    if (self.transformer)
        value = self.transformer(value);

    if (![value isKindOfClass:[NSString class]]) {
        if ([value isKindOfClass:[NSNumber class]])
            value = [value stringValue];
        else
            value = [value description];
    }
    
    return value;
}

- (UIImage *)imageForObject:(id)object
{
    id value = [object valueForKeyPath:self.keyPath];
    if (!self.imageTransformer || [value isKindOfClass:[NSString class]])
        return nil;

    return self.imageTransformer(value);
}

@end


@interface AAPLKeyValueDataSource ()
@property (nonatomic, copy) NSArray *unfilteredItems;
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
    _titleColumnWidth = CGFLOAT_MIN;

    self.allowsSelection = NO;

    return self;
}

- (void)setObject:(id)object
{
    if (object == _object)
        return;
    
    _object = object;
    // reset the items based on the unfiltered items, because the object has changed.
    [self setItems:self.unfilteredItems];
    [self notifySectionsRefreshed:[NSIndexSet indexSetWithIndex:0]];
}

- (void)setItems:(NSArray *)items
{
    // before passing along to super, filter out any items that result in a nil value. This relies on the object being set before calling items.
    self.unfilteredItems = items;

    NSMutableArray *newItems = [NSMutableArray array];
    [items enumerateObjectsUsingBlock:^(AAPLKeyValueItem *item, NSUInteger idx, BOOL *stop) {
        NSString *value = [item valueForObject:_object];

        if (value.length)
            [newItems addObject:item];
    }];

    [super setItems:newItems];
}

- (void)registerReusableViewsWithCollectionView:(UICollectionView *)collectionView
{
    [super registerReusableViewsWithCollectionView:collectionView];
    [collectionView registerClass:[AAPLKeyValueCell class] forCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLKeyValueCell)];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AAPLKeyValueCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:AAPLReusableIdentifierFromClass(AAPLKeyValueCell) forIndexPath:indexPath];
    AAPLKeyValueItem *item = [self itemAtIndexPath:indexPath];

    NSString *value = [item valueForObject:_object];
    
    if (_titleColumnWidth != CGFLOAT_MIN)
        cell.titleColumnWidth = _titleColumnWidth;

    switch (item.itemType) {
        case AAPLKeyValueItemTypeDefault:
            [cell configureWithTitle:item.localizedTitle value:value];
            break;
        case AAPLKeyValueItemTypeButton:
            [cell configureWithTitle:item.localizedTitle buttonTitle:value buttonImage:[item imageForObject:_object] action:item.action];
            break;
        case AAPLKeyValueItemTypeURL:
            [cell configureWithTitle:item.localizedTitle URL:value];
            break;
    }

    return cell;
}

@end
