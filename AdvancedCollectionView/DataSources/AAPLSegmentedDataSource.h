/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of AAPLDataSource with multiple child data sources, however, only one data source will be visible at a time. Load content messages will be sent only to the selected data source. When selected, if a data source is still in the initial state, it will receive a load content message.
  
 */

#import "AAPLDataSource.h"

/// A data source that switches among a number of child data sources.
@interface AAPLSegmentedDataSource : AAPLDataSource

/// Add a data source to the end of the collection. The title property of the data source will be used to populate a new segment in the UISegmentedControl associated with this data source.
- (void)addDataSource:(AAPLDataSource *)dataSource;

/// Remove the data source from the collection.
- (void)removeDataSource:(AAPLDataSource *)dataSource;

/// Clear the collection of data sources.
- (void)removeAllDataSources;

/// The default segmented control header for this data source. To hide this header, use shouldDisplayDefaultHeader = NO.
@property (nonatomic, readonly) AAPLLayoutSupplementaryMetrics *segmentedControlHeader;

/// The collection of data sources contained within this segmented data source.
@property (nonatomic, readonly) NSArray *dataSources;

/// Should the data source create a default header that allows switching between the data sources. Set to NO if switching is accomplished through some other means. Default value is YES.
@property (nonatomic) BOOL shouldDisplayDefaultHeader;

/// A reference to the selected data source.
@property (nonatomic, strong) AAPLDataSource *selectedDataSource;

/// The index of the selected data source in the collection.
@property (nonatomic) NSInteger selectedDataSourceIndex;

/// Set the selected data source with animation. By default, setting the selected data source is not animated.
- (void)setSelectedDataSource:(AAPLDataSource *)selectedDataSource animated:(BOOL)animated;

/// Set the index of the selected data source with optional animation. By default, setting the selected data source index is not animated.
- (void)setSelectedDataSourceIndex:(NSInteger)selectedDataSourceIndex animated:(BOOL)animated;

/// Call this method to configure a segmented control with the titles of the data sources. This method also sets the target & action of the segmented control to switch the selected data source.
- (void)configureSegmentedControl:(UISegmentedControl *)segmentedControl;

@end
