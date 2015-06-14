/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Classes used to define the layout metrics.
 */

#import "AAPLLayoutMetrics_Private.h"
#import "AAPLTheme.h"

#define AAPL_SET_PROP_AND_FLAG(propName, value) _##propName = (value); _flags.propName = YES;
#define AAPL_COPY_PROP_FROM_TO(propName, source, dest) if (source->_flags.propName) dest.propName = source.propName;
#define AAPL_RESOLVE_PROP_FROM_THEME_PROP(propName, themeProp) if (!_flags.propName) _##propName = _theme.themeProp;

NSString * const AAPLCollectionElementKindPlaceholder = @"AAPLCollectionElementKindPlaceholder";
CGFloat const AAPLCollectionViewAutomaticHeight = -1000;
NSInteger const AAPLGlobalSectionIndex = NSIntegerMax;

@interface AAPLSupplementaryItem ()
@property (nonatomic, readwrite, copy) NSString *elementKind;
@end

@implementation AAPLSupplementaryItem {
    struct {
        unsigned char height : 1;
        unsigned char estimatedHeight : 1;
        unsigned char hidden : 1;
        unsigned char shouldPin : 1;
        unsigned char visibleWhileShowingPlaceholder : 1;
        unsigned char backgroundColor : 1;
        unsigned char pinnedBackgroundColor : 1;
        unsigned char pinnedSeparatorColor : 1;
        unsigned char separatorColor : 1;
        unsigned char selectedBackgroundColor : 1;
        unsigned char layoutMargins : 1;
        unsigned char showsSeparator : 1;
    } _flags;
}

- (instancetype)initWithElementKind:(NSString *)kind
{
    self = [super init];
    if (!self)
        return nil;

    _elementKind = [kind copy];
    _height = AAPLCollectionViewAutomaticHeight;
    _estimatedHeight = 44;
    return self;
}


- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"Don't call %@.", @(__PRETTY_FUNCTION__)];
    return nil;
}

- (NSString *)reuseIdentifier
{
    if (_reuseIdentifier)
        return _reuseIdentifier;

    return NSStringFromClass(_supplementaryViewClass);
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    AAPLSupplementaryItem *item = [[self.class alloc] init];
    if (!item)
        return nil;

    item->_reuseIdentifier = [_reuseIdentifier copy];
    item->_supplementaryViewClass = _supplementaryViewClass;
    item->_configureView = _configureView;

    item->_height = _height;
    item->_estimatedHeight = _estimatedHeight;
    item->_hidden = _hidden;
    item->_shouldPin = _shouldPin;
    item->_visibleWhileShowingPlaceholder = _visibleWhileShowingPlaceholder;
    item->_backgroundColor = _backgroundColor;
    item->_selectedBackgroundColor = _selectedBackgroundColor;
    item->_layoutMargins = _layoutMargins;
    item->_separatorColor = _separatorColor;
    item->_pinnedBackgroundColor = _pinnedBackgroundColor;
    item->_pinnedSeparatorColor = _pinnedSeparatorColor;
    item->_showsSeparator = _showsSeparator;
    item->_elementKind = [_elementKind copy];
    return item;
}

- (void)configureWithBlock:(AAPLSupplementaryItemConfigurationBlock)block
{
    NSParameterAssert(block != nil);

    if (!_configureView) {
        self.configureView = block;
        return;
    }

    // chain the old with the new
    AAPLSupplementaryItemConfigurationBlock oldConfigBlock = _configureView;
    self.configureView = ^(UICollectionReusableView *view, AAPLDataSource *dataSource, NSIndexPath *indexPath) {
        oldConfigBlock(view, dataSource, indexPath);
        block(view, dataSource, indexPath);
    };
}

- (void)setHeight:(CGFloat)height
{
    AAPL_SET_PROP_AND_FLAG(height, height);
}

- (void)setEstimatedHeight:(CGFloat)estimatedHeight
{
    AAPL_SET_PROP_AND_FLAG(estimatedHeight, estimatedHeight);
}

- (void)setHidden:(BOOL)hidden
{
    AAPL_SET_PROP_AND_FLAG(hidden, hidden);
}

- (void)setShouldPin:(BOOL)shouldPin
{
    AAPL_SET_PROP_AND_FLAG(shouldPin, shouldPin);
}

- (void)setVisibleWhileShowingPlaceholder:(BOOL)visibleWhileShowingPlaceholder
{
    AAPL_SET_PROP_AND_FLAG(visibleWhileShowingPlaceholder, visibleWhileShowingPlaceholder);
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    AAPL_SET_PROP_AND_FLAG(backgroundColor, backgroundColor);
}

- (void)setSelectedBackgroundColor:(UIColor *)selectedBackgroundColor
{
    AAPL_SET_PROP_AND_FLAG(selectedBackgroundColor, selectedBackgroundColor);
}

- (void)setPinnedBackgroundColor:(UIColor *)pinnedBackgroundColor
{
    AAPL_SET_PROP_AND_FLAG(pinnedBackgroundColor, pinnedBackgroundColor);
}

- (void)setPinnedSeparatorColor:(UIColor *)pinnedSeparatorColor
{
    AAPL_SET_PROP_AND_FLAG(pinnedSeparatorColor, pinnedSeparatorColor);
}

- (void)setSeparatorColor:(UIColor *)separatorColor
{
    AAPL_SET_PROP_AND_FLAG(separatorColor, separatorColor);
}

- (void)setLayoutMargins:(UIEdgeInsets)layoutMargins
{
    AAPL_SET_PROP_AND_FLAG(layoutMargins, layoutMargins);
}

- (void)setShowsSeparator:(BOOL)showsSeparator
{
    AAPL_SET_PROP_AND_FLAG(showsSeparator, showsSeparator);
}

- (BOOL)hasEstimatedHeight
{
    return self.height == AAPLCollectionViewAutomaticHeight;
}

- (CGFloat)fixedHeight
{
    if (self.height == AAPLCollectionViewAutomaticHeight)
        return self.estimatedHeight;
    return self.height;
}

- (void)applyValuesFromMetrics:(AAPLSupplementaryItem *)metrics
{
    if (!metrics)
        return;

    AAPL_COPY_PROP_FROM_TO(layoutMargins, metrics, self);
    AAPL_COPY_PROP_FROM_TO(separatorColor, metrics, self);
    AAPL_COPY_PROP_FROM_TO(pinnedSeparatorColor, metrics, self);
    AAPL_COPY_PROP_FROM_TO(backgroundColor, metrics, self);
    AAPL_COPY_PROP_FROM_TO(pinnedBackgroundColor, metrics, self);
    AAPL_COPY_PROP_FROM_TO(selectedBackgroundColor, metrics, self);
    AAPL_COPY_PROP_FROM_TO(height, metrics, self);
    AAPL_COPY_PROP_FROM_TO(estimatedHeight, metrics, self);
    AAPL_COPY_PROP_FROM_TO(hidden, metrics, self);
    AAPL_COPY_PROP_FROM_TO(shouldPin, metrics, self);
    AAPL_COPY_PROP_FROM_TO(visibleWhileShowingPlaceholder, metrics, self);
    AAPL_COPY_PROP_FROM_TO(showsSeparator, metrics, self);

    _supplementaryViewClass = metrics->_supplementaryViewClass;
    _configureView = metrics->_configureView;
    _reuseIdentifier = [metrics->_reuseIdentifier copy];
}

@end



@implementation AAPLSectionMetrics {
    struct {
        unsigned char rowHeight : 1;
        unsigned char estimatedRowHeight : 1;
        unsigned char showsSectionSeparator : 1;
        unsigned char showsSectionSeparatorWhenLastSection : 1;
        unsigned char backgroundColor : 1;
        unsigned char selectedBackgroundColor : 1;
        unsigned char separatorColor : 1;
        unsigned char sectionSeparatorColor : 1;
        unsigned char numberOfColumns : 1;
        unsigned char theme : 1;
        unsigned char padding : 1;
        unsigned char showsRowSeparator : 1;
    } _flags;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _rowHeight = AAPLCollectionViewAutomaticHeight;
    _estimatedRowHeight = 44;
    _numberOfColumns = 1;
    // If there's more than one column AND there's a separator color specified, we want to show a column separator by default.
    _showsColumnSeparator = YES;
    _theme = [AAPLTheme theme];
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    AAPLSectionMetrics *metrics = [[self.class alloc] init];
    if (!metrics)
        return nil;

    metrics->_rowHeight = _rowHeight;
    metrics->_estimatedRowHeight = _estimatedRowHeight;
    metrics->_numberOfColumns = _numberOfColumns;
    metrics->_padding = _padding;
    metrics->_showsColumnSeparator = _showsColumnSeparator;
    metrics->_separatorInsets = _separatorInsets;
    metrics->_backgroundColor = _backgroundColor;
    metrics->_selectedBackgroundColor = _selectedBackgroundColor;
    metrics->_separatorColor = _separatorColor;
    metrics->_sectionSeparatorColor = _sectionSeparatorColor;
    metrics->_sectionSeparatorInsets = _sectionSeparatorInsets;
    metrics->_showsSectionSeparator = _showsSectionSeparator;
    metrics->_showsSectionSeparatorWhenLastSection = _showsSectionSeparatorWhenLastSection;
    metrics->_cellLayoutOrder = _cellLayoutOrder;
    metrics->_flags = _flags;
    metrics->_theme = _theme;
    metrics->_showsRowSeparator = _showsColumnSeparator;
    return metrics;
}

- (void)setRowHeight:(CGFloat)rowHeight
{
    AAPL_SET_PROP_AND_FLAG(rowHeight, rowHeight);
}

- (void)setEstimatedRowHeight:(CGFloat)estimatedRowHeight
{
    AAPL_SET_PROP_AND_FLAG(estimatedRowHeight, estimatedRowHeight);
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    AAPL_SET_PROP_AND_FLAG(backgroundColor, backgroundColor);
}

- (void)setSelectedBackgroundColor:(UIColor *)selectedBackgroundColor
{
    AAPL_SET_PROP_AND_FLAG(selectedBackgroundColor, selectedBackgroundColor);
}

- (void)setSeparatorColor:(UIColor *)separatorColor
{
    AAPL_SET_PROP_AND_FLAG(separatorColor, separatorColor);
}

- (void)setSectionSeparatorColor:(UIColor *)sectionSeparatorColor
{
    AAPL_SET_PROP_AND_FLAG(sectionSeparatorColor, sectionSeparatorColor);
}

- (void)setShowsSectionSeparatorWhenLastSection:(BOOL)showsSectionSeparatorWhenLastSection
{
    AAPL_SET_PROP_AND_FLAG(showsSectionSeparatorWhenLastSection, showsSectionSeparatorWhenLastSection);
}

- (void)setNumberOfColumns:(NSInteger)numberOfColumns
{
    AAPL_SET_PROP_AND_FLAG(numberOfColumns, numberOfColumns);
}

- (void)setPadding:(UIEdgeInsets)padding
{
    AAPL_SET_PROP_AND_FLAG(padding, padding);
}

- (void)setTheme:(AAPLTheme *)theme
{
    AAPL_SET_PROP_AND_FLAG(theme, theme);
}

- (void)setShowsRowSeparator:(BOOL)showsRowSeparator
{
    AAPL_SET_PROP_AND_FLAG(showsRowSeparator, showsRowSeparator);
}

- (void)setShowsSectionSeparator:(BOOL)showsSectionSeparator
{
    AAPL_SET_PROP_AND_FLAG(showsSectionSeparator, showsSectionSeparator);
}

- (void)applyValuesFromMetrics:(AAPLSectionMetrics *)metrics
{
    if (!metrics)
        return;

    if (!UIEdgeInsetsEqualToEdgeInsets(metrics.separatorInsets, UIEdgeInsetsZero))
        self.separatorInsets = metrics.separatorInsets;

    if (!UIEdgeInsetsEqualToEdgeInsets(metrics.sectionSeparatorInsets, UIEdgeInsetsZero))
        self.sectionSeparatorInsets = metrics.sectionSeparatorInsets;

    AAPL_COPY_PROP_FROM_TO(rowHeight, metrics, self);
    AAPL_COPY_PROP_FROM_TO(estimatedRowHeight, metrics, self);
    AAPL_COPY_PROP_FROM_TO(numberOfColumns, metrics, self);
    AAPL_COPY_PROP_FROM_TO(backgroundColor, metrics, self);
    AAPL_COPY_PROP_FROM_TO(selectedBackgroundColor, metrics, self);
    AAPL_COPY_PROP_FROM_TO(sectionSeparatorColor, metrics, self);
    AAPL_COPY_PROP_FROM_TO(separatorColor, metrics, self);
    AAPL_COPY_PROP_FROM_TO(showsSectionSeparatorWhenLastSection, metrics, self);
    AAPL_COPY_PROP_FROM_TO(theme, metrics, self);
    AAPL_COPY_PROP_FROM_TO(padding, metrics, self);
    AAPL_COPY_PROP_FROM_TO(showsRowSeparator, metrics, self);
    AAPL_COPY_PROP_FROM_TO(showsSectionSeparator, metrics, self);
}

- (void)resolveMissingValuesFromTheme
{
    AAPL_RESOLVE_PROP_FROM_THEME_PROP(backgroundColor, backgroundColor);
    AAPL_RESOLVE_PROP_FROM_THEME_PROP(selectedBackgroundColor, selectedBackgroundColor);
    AAPL_RESOLVE_PROP_FROM_THEME_PROP(separatorColor, separatorColor);
    AAPL_RESOLVE_PROP_FROM_THEME_PROP(sectionSeparatorColor, separatorColor);
}

@end
