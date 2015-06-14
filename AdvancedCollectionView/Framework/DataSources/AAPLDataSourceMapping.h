/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A subclass of AAPLDataSource with multiple child data sources. Child data sources may have multiple sections. Load content messages will be sent to all child data sources.
 
  This file contains some classes used internally by the AAPLComposedDataSource to manage the mapping between external NSIndexPaths and child data source NSIndexPaths. Of particular interest is the AAPLComposedViewWrapper which proxies messages to UICollectionView.
 */

@import UIKit;

NS_ASSUME_NONNULL_BEGIN




@class AAPLDataSource, AAPLShadowRegistrar;

/// Maps global sections to local sections for a given data source
@interface AAPLDataSourceMapping : NSObject <NSCopying>

- (instancetype)initWithDataSource:(AAPLDataSource *)dataSource NS_DESIGNATED_INITIALIZER;

/// A convenience initializer to create a data source mapping with a data source and an initial global section index. For mappings that will not change, this alleviates the need to call -updateMappingStartingAtGlobalSection:withBlock:
- (instancetype)initWithDataSource:(AAPLDataSource *)dataSource globalSectionIndex:(NSInteger)sectionIndex;

/// The data source associated with this mapping
@property (nonatomic, strong) AAPLDataSource * dataSource;

/// The number of sections in this mapping
@property (nonatomic, readonly) NSInteger numberOfSections;

/// Return the local section for a global section
- (NSInteger)localSectionForGlobalSection:(NSInteger)globalSection;

/// Return the global section for a local section
- (NSInteger)globalSectionForLocalSection:(NSInteger)localSection;

/// Return a local index path for a global index path. Returns nil when the global indexPath does not map locally.
- (nullable NSIndexPath *)localIndexPathForGlobalIndexPath:(NSIndexPath *)globalIndexPath;

/// Return a global index path for a local index path
- (NSIndexPath *)globalIndexPathForLocalIndexPath:(NSIndexPath *)localIndexPath;

/// Return an array of local index paths from an array of global index paths
- (NSArray<NSIndexPath *> *)localIndexPathsForGlobalIndexPaths:(NSArray<NSIndexPath *> *)globalIndexPaths;

/// Return an array of global index paths from an array of local index paths
- (NSArray<NSIndexPath *> *)globalIndexPathsForLocalIndexPaths:(NSArray<NSIndexPath *> *)localIndexPaths;

/// The block argument is called once for each mapped section and passed the global section index.
- (void)updateMappingStartingAtGlobalSection:(NSInteger)globalSection withBlock:(void(^)(NSInteger globalSection))block;


- (instancetype)init NS_UNAVAILABLE;
@end



/// An object that pretends to be either a UITableView or UICollectionView that handles transparently mapping from local to global index paths
@interface AAPLCollectionViewWrapper : NSObject

/// Factory method that will determine whether the wrapper is measuring based on the collection view. If the collectionView is actually an instance of AAPLCollectionViewWrapper, the value will be pulled from the collectionView. Otherwise, the default is NO.
+ (__kindof UIView *)wrapperForCollectionView:(UICollectionView *)collectionView mapping:(nullable AAPLDataSourceMapping *)mapping;

+ (__kindof UIView *)wrapperForCollectionView:(UICollectionView *)collectionView mapping:(nullable AAPLDataSourceMapping *)mapping measuring:(BOOL)measuring;

@property (nonatomic, strong, readonly) UICollectionView *collectionView;
@property (nullable, nonatomic, strong, readonly) AAPLDataSourceMapping *mapping;
/// Is this wrapper being used for measuring the layout?
@property (nonatomic, readonly) BOOL measuring;

@end




NS_ASSUME_NONNULL_END
