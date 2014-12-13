/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A subclass of AAPLDataSource with multiple child data sources. Child data sources may have multiple sections. Load content messages will be sent to all child data sources.
  
  This file contains some classes used internally by the AAPLComposedDataSource to manage the mapping between external NSIndexPaths and child data source NSIndexPaths. Of particular interest is the AAPLComposedViewWrapper which proxies messages to UICollectionView.
  
 */

#import "AAPLComposedDataSource.h"

@class AAPLDataSource;

/// Maps global sections to local sections for a given data source
@interface AAPLComposedMapping : NSObject <NSCopying>

- (instancetype)initWithDataSource:(AAPLDataSource *)dataSource;

/// The data source associated with this mapping
@property (nonatomic, strong) AAPLDataSource * dataSource;

/// The number of sections in this mapping
@property (nonatomic, readonly) NSInteger sectionCount;

/// Return the local section for a global section
- (NSUInteger)localSectionForGlobalSection:(NSUInteger)globalSection;

/// Return the global section for a local section
- (NSUInteger)globalSectionForLocalSection:(NSUInteger)localSection;

/// Return a local index path for a global index path
- (NSIndexPath *)localIndexPathForGlobalIndexPath:(NSIndexPath *)globalIndexPath;

/// Return a global index path for a local index path
- (NSIndexPath *)globalIndexPathForLocalIndexPath:(NSIndexPath *)localIndexPath;

/// Return an array of local index paths from an array of global index paths
- (NSArray *)localIndexPathsForGlobalIndexPaths:(NSArray *)globalIndexPaths;

/// Return an array of global index paths from an array of local index paths
- (NSArray *)globalIndexPathsForLocalIndexPaths:(NSArray *)localIndexPaths;

/// Update the mapping of local sections to global sections.
- (NSUInteger)updateMappingsStartingWithGlobalSection:(NSUInteger)globalSection;

@end

/// An object that pretends to be either a UITableView or UICollectionView that handles transparently mapping from local to global index paths
@interface AAPLComposedViewWrapper : NSObject

+ (id)wrapperForView:(UIView *)view mapping:(AAPLComposedMapping *)mapping;

@property (nonatomic, retain) UIView *wrappedView;
@property (nonatomic, retain) AAPLComposedMapping *mapping;

@end
