/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of UICollectionViewLayoutAttributes with additional attributes required by the AAPLCollectionViewGridLayout, AAPLCollectionViewCell, and AAPLPinnableHeaderView classes.
  
 */

#import "AAPLCollectionViewGridLayoutAttributes_Private.h"

@implementation AAPLCollectionViewGridLayoutAttributes

- (NSUInteger)hash
{
    NSUInteger prime = 31;
    NSUInteger result = 1;

    result = prime * result + [super hash];
    result = prime * result + _pinnedHeader;
    result = prime * result + _columnIndex;
    result = prime * result + [_backgroundColor hash];
    result = prime * result + [_selectedBackgroundColor hash];
    result = prime * result + _padding.top;
    result = prime * result + _padding.left;
    result = prime * result + _padding.bottom;
    result = prime * result + _padding.right;
    result = prime * result + _editing;
    result = prime * result + _movable;
    return result;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[AAPLCollectionViewGridLayoutAttributes class]])
        return NO;

    AAPLCollectionViewGridLayoutAttributes *other = object;
    if (![super isEqual:other])
        return NO;

    if (_editing != other->_editing || _movable != other->_movable)
        return NO;

    if (_pinnedHeader != other->_pinnedHeader || _columnIndex != other->_columnIndex)
        return NO;

    if (_backgroundColor != other->_backgroundColor && ![_backgroundColor isEqual:other->_backgroundColor])
        return NO;

    if (_selectedBackgroundColor != other->_selectedBackgroundColor && ![_selectedBackgroundColor isEqual:other->_selectedBackgroundColor])
        return NO;

    if (!UIEdgeInsetsEqualToEdgeInsets(_padding, other->_padding))
        return NO;

    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    AAPLCollectionViewGridLayoutAttributes *attributes = [super copyWithZone:zone];
    attributes->_backgroundColor = _backgroundColor;
    attributes->_pinnedHeader = _pinnedHeader;
    attributes->_columnIndex = _columnIndex;
    attributes->_backgroundColor = _backgroundColor;
    attributes->_selectedBackgroundColor = _selectedBackgroundColor;
    attributes->_padding = _padding;
    attributes->_editing = _editing;
    attributes->_movable = _movable;
    attributes->_unpinnedY = _unpinnedY;
    return attributes;
}

@end
