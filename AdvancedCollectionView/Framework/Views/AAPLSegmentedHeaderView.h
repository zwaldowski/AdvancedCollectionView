/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A header view with a UISegmentedControl for displaying the titles of child data sources in a segmented data source.
 */

#import "AAPLPinnableHeaderView.h"

NS_ASSUME_NONNULL_BEGIN




typedef NS_ENUM(NSInteger, AAPLSegmentedHeaderAlignment) {
    AAPLSegmentedHeaderAlignmentCenter = 0,
    AAPLSegmentedHeaderAlignmentLeading = 1,
    AAPLSegmentedHeaderAlignmentTrailing = 2
};




/// A header view with a UISegmentedControl for displaying the titles of child data sources in a segmented data source.
@interface AAPLSegmentedHeaderView : AAPLPinnableHeaderView

@property (nonatomic, strong, readonly) UISegmentedControl *segmentedControl;
/// Default value is AAPLSegmentedHeaderAlignmentCenter
@property (nonatomic) AAPLSegmentedHeaderAlignment headerAlignment;

- (instancetype)initWithFrame:(CGRect)frame headerAlignment:(AAPLSegmentedHeaderAlignment)headerAlignment NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@end




NS_ASSUME_NONNULL_END
