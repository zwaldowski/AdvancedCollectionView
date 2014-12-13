/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A basic collection view cell with a primary and secondary label. When styled using AAPLBasicCellStyleDefault, the primary label is on the left and the secondary label is on the right. When styled with AAPLBasicCellStyleSubtitle, both the primary and secondar labels are on the left with the primary above the secondary.
  
 */

#import "AAPLCollectionViewCell.h"

typedef enum {
    /// Primary and secondary labels are the same size with the primary label left aligned and the secondary right aligned
    AAPLBasicCellStyleDefault,
    /// Primary and secondary labels are aligned one above the other. Primary label is larger than the secondary label.
    AAPLBasicCellStyleSubtitle
} AAPLBasicCellStyle;

/// About as bog simple a collection view cell as you can get.
@interface AAPLBasicCell : AAPLCollectionViewCell
@property (nonatomic) AAPLBasicCellStyle style;
@property (nonatomic) UIEdgeInsets contentInsets;
@property (nonatomic, readonly) UILabel *primaryLabel;
@property (nonatomic, readonly) UILabel *secondaryLabel;
@end
