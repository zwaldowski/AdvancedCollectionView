/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A simple AAPLCollectionViewCell that displays a large block of text.
 */

#import "AAPLCollectionViewCell.h"

NS_ASSUME_NONNULL_BEGIN




/// A simple AAPLCollectionViewCell that displays a large block of text.
@interface AAPLTextValueCell : AAPLCollectionViewCell

@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) BOOL shouldAllowTruncation;

- (void)configureWithTitle:(NSString *)title text:(NSString *)text;

@end




NS_ASSUME_NONNULL_END
