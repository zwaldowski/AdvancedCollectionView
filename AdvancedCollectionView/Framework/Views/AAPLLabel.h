/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A truncating version of UILabel that draws a more… link at the end of the text.
 */

NS_ASSUME_NONNULL_BEGIN




/// A subclass of UILabel that draws an additional string when the text is truncated.
@interface AAPLLabel : UILabel

/// The text to display when truncated. This is displayed to the right of the text. Default is "more". The truncationText is displayed in the tintColor of this view. This property can be reset to the default by setting it to nil.
@property (null_resettable, nonatomic, copy) NSString *truncationText;

@end




NS_ASSUME_NONNULL_END
