/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of UICollectionViewLayoutAttributes with additional attributes required by the AAPLCollectionViewGridLayout, AAPLCollectionViewCell, and AAPLPinnableHeaderView classes.
 */

#import "AAPLCollectionViewLayoutAttributes_Private.h"

@implementation AAPLCollectionViewLayoutAttributes

- (NSUInteger)hash
{
    NSUInteger prime = 31;
    NSUInteger result = 1;

    result = prime * result + [super hash];
    result = prime * result + _pinnedHeader;
    result = prime * result + _columnIndex;
    result = prime * result + [_backgroundColor hash];
    result = prime * result + [_selectedBackgroundColor hash];
    result = prime * result + (NSUInteger)_layoutMargins.top;
    result = prime * result + (NSUInteger)_layoutMargins.left;
    result = prime * result + (NSUInteger)_layoutMargins.bottom;
    result = prime * result + (NSUInteger)_layoutMargins.right;
    result = prime * result + _editing;
    result = prime * result + _movable;
    result = prime * result + _shouldCalculateFittingSize;
    return result;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[AAPLCollectionViewLayoutAttributes class]])
        return NO;

    AAPLCollectionViewLayoutAttributes *other = object;
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

    if (!UIEdgeInsetsEqualToEdgeInsets(_layoutMargins, other->_layoutMargins))
        return NO;

    if (_shouldCalculateFittingSize != other->_shouldCalculateFittingSize)
        return NO;

    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    AAPLCollectionViewLayoutAttributes *attributes = [super copyWithZone:zone];
    attributes->_backgroundColor = _backgroundColor;
    attributes->_pinnedHeader = _pinnedHeader;
    attributes->_columnIndex = _columnIndex;
    attributes->_backgroundColor = _backgroundColor;
    attributes->_selectedBackgroundColor = _selectedBackgroundColor;
    attributes->_layoutMargins = _layoutMargins;
    attributes->_editing = _editing;
    attributes->_movable = _movable;
    attributes->_unpinnedY = _unpinnedY;
    attributes->_shouldCalculateFittingSize = _shouldCalculateFittingSize;
    attributes->_theme = _theme;
    attributes->_simulatesSelection = _simulatesSelection;
    attributes->_pinnedSeparatorColor = _pinnedSeparatorColor;
    attributes->_separatorColor = _separatorColor;
    attributes->_pinnedBackgroundColor = _pinnedBackgroundColor;
    attributes->_showsSeparator = _showsSeparator;
    return attributes;
}

@end
