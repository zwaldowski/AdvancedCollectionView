/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Classes used to define the layout metrics.
  
 */

#import "AAPLLayoutMetrics_Private.h"

NSString * const AAPLCollectionElementKindPlaceholder = @"placeholder";
CGFloat const AAPLRowHeightVariable = -1000;
CGFloat const AAPLRowHeightRemainder = -1001;
NSInteger const AAPLGlobalSection = NSIntegerMax;

@implementation AAPLLayoutSupplementaryMetrics

- (NSString *)reuseIdentifier
{
    if (_reuseIdentifier)
        return _reuseIdentifier;

    return NSStringFromClass(_supplementaryViewClass);
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    AAPLLayoutSupplementaryMetrics *item = [[AAPLLayoutSupplementaryMetrics alloc] init];
    if (!item)
        return nil;

    item->_kind = [_kind copy];
    item->_reuseIdentifier = [_reuseIdentifier copy];
    item->_height = _height;
    item->_hidden = _hidden;
    item->_shouldPin = _shouldPin;
    item->_visibleWhileShowingPlaceholder = _visibleWhileShowingPlaceholder;
    item->_supplementaryViewClass = _supplementaryViewClass;
    item->_createView = _createView;
    item->_configureView = _configureView;
    item->_backgroundColor = _backgroundColor;
    item->_selectedBackgroundColor = _selectedBackgroundColor;
    item->_padding = _padding;
    return item;
}

- (void)configureWithBlock:(AAPLLayoutSupplementaryItemConfigurationBlock)block
{
    NSParameterAssert(block != nil);

    if (!_configureView) {
        self.configureView = block;
        return;
    }

    // chain the old with the new
    AAPLLayoutSupplementaryItemConfigurationBlock oldConfigBlock = _configureView;
    self.configureView = ^(UICollectionReusableView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        oldConfigBlock(view, dataSource, indexPath);
        block(view, dataSource, indexPath);
    };
}

@end

@implementation AAPLLayoutSectionMetrics {
    struct {
        unsigned int backgroundColor : 1;
        unsigned int selectedBackgroundColor : 1;
        unsigned int separatorColor : 1;
        unsigned int separators : 1;
    } _flags;
    NSMutableArray *_supplementaryViews;
}

@synthesize supplementaryViews = _supplementaryViews;

+ (instancetype)metrics
{
    return [[self alloc] init];
}

+ (instancetype)defaultMetrics
{
    AAPLLayoutSectionMetrics *metrics = [[self alloc] init];
    metrics.rowHeight = 44;
    metrics.numberOfColumns = 1;
    return metrics;
}

- (instancetype)init
{
    self = [super init];
    if (!self) { return nil; }

    // If there's more than one column AND there's a separator color specified, we want to show a column separator by default.
    _separators = AAPLSeparatorOptionSupplements | AAPLSeparatorOptionRows | AAPLSeparatorOptionColumns | AAPLSeparatorOptionAfterSection;

    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    AAPLLayoutSectionMetrics *metrics = [[AAPLLayoutSectionMetrics alloc] init];
    if (!metrics)
        return nil;

    metrics->_rowHeight = _rowHeight;
    metrics->_numberOfColumns = _numberOfColumns;
    metrics->_padding = _padding;
    metrics->_separatorInsets = _separatorInsets;
    metrics->_backgroundColor = _backgroundColor;
    metrics->_selectedBackgroundColor = _selectedBackgroundColor;
    metrics->_separatorColor = _separatorColor;
    metrics->_hasPlaceholder = _hasPlaceholder;
    metrics->_cellLayoutOrder = _cellLayoutOrder;
    metrics->_separators = _separators;
    metrics->_supplementaryViews = [_supplementaryViews mutableCopy];
    metrics->_flags = _flags;
    return metrics;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    _backgroundColor = backgroundColor;
    _flags.backgroundColor = YES;
}

- (void)setSelectedBackgroundColor:(UIColor *)selectedBackgroundColor
{
    _selectedBackgroundColor = selectedBackgroundColor;
    _flags.selectedBackgroundColor = YES;
}

- (void)setSeparatorColor:(UIColor *)separatorColor
{
    _separatorColor = separatorColor;
    _flags.separatorColor = YES;
}

- (void)setSeparators:(AAPLSeparatorOption)separators
{
    _separators = separators;
    _flags.separators = YES;
}

- (void)setSupplementaryViews:(NSArray *)supplementaryViews {
    _supplementaryViews = [NSMutableArray arrayWithArray:supplementaryViews];
}

- (AAPLLayoutSupplementaryMetrics *)newSupplementaryMetricsOfKind:(NSString *)kind
{
    AAPLLayoutSupplementaryMetrics *info = [[AAPLLayoutSupplementaryMetrics alloc] init];
    info.kind = kind;
    
    if (!_supplementaryViews) {
        _supplementaryViews = NSMutableArray.new;
    }
    
    [_supplementaryViews addObject:info];
    
    return info;
}

- (void)applyValuesFromMetrics:(AAPLLayoutSectionMetrics *)metrics
{
    if (!metrics)
        return;

    if (!UIEdgeInsetsEqualToEdgeInsets(metrics.padding, UIEdgeInsetsZero))
        self.padding = metrics.padding;

    if (!UIEdgeInsetsEqualToEdgeInsets(metrics.separatorInsets, UIEdgeInsetsZero))
        self.separatorInsets = metrics.separatorInsets;

    if (metrics.rowHeight)
        self.rowHeight = metrics.rowHeight;

    if (metrics.numberOfColumns)
        self.numberOfColumns = metrics.numberOfColumns;

    if (metrics->_flags.backgroundColor)
        self.backgroundColor = metrics.backgroundColor;

    if (metrics->_flags.selectedBackgroundColor)
        self.selectedBackgroundColor = metrics.selectedBackgroundColor;

    if (metrics->_flags.separatorColor)
        self.separatorColor = metrics.separatorColor;
    
    if (metrics->_flags.separators) {
        self.separators = metrics.separators;
    }
    
    self.hasPlaceholder |= metrics.hasPlaceholder;
    
    if (metrics.supplementaryViews) {
        [_supplementaryViews addObjectsFromArray:metrics.supplementaryViews];
    }
}

@end
