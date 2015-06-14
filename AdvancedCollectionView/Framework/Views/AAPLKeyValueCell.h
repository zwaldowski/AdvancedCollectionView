/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A cell for displaying key value items.
 */

#import "AAPLCollectionViewCell.h"

NS_ASSUME_NONNULL_BEGIN




/// A simple cell that displays key / value information.
@interface AAPLKeyValueCell : AAPLCollectionViewCell

/// The width of the title column. This may need tweaking if you have long titles.
@property (nonatomic) CGFloat titleColumnWidth;

/// Configure a key value cell with a title and a value.
- (void)configureWithTitle:(NSString *)title value:(NSString *)value;

/// Configure a key value cell with a title and a button. Either the button title or image must be specified.
- (void)configureWithTitle:(NSString *)title buttonTitle:(nullable NSString *)buttonTitle buttonImage:(nullable UIImage *)image action:(SEL)action;

/// Configure a key value cell with a title and an URL.
- (void)configureWithTitle:(NSString *)title URL:(NSString *)url;

/// Should the text value be truncated to fit in the available space? Default is YES.
@property (nonatomic) BOOL shouldTruncateValue;

@end




NS_ASSUME_NONNULL_END
