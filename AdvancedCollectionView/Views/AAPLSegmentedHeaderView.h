/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A header view with a UISegmentedControl for displaying the titles of child data sources in a segmented data source.
  
 */

#import "AAPLPinnableHeaderView.h"


@interface AAPLSegmentedHeaderView : AAPLPinnableHeaderView

@property (nonatomic, strong, readonly) UISegmentedControl *segmentedControl;

@end
