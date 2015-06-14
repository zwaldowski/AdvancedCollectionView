/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The cat detail data source, of course. Initialised with a cat instance, this data source will fetch the detail information about that cat.
 */

#import "AAPLComposedDataSource.h"

@class AAPLCat;

@interface AAPLCatDetailDataSource : AAPLComposedDataSource

- (instancetype)initWithCat:(AAPLCat *)cat NS_DESIGNATED_INITIALIZER;

@end
