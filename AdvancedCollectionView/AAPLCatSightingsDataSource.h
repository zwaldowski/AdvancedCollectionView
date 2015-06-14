/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A basic data source for the sightings of a particular cat. When initialised with a cat, this data source will fetch the cat sightings.
 */

#import "AAPLBasicDataSource.h"

@class AAPLCat, AAPLCatSighting;

@interface AAPLCatSightingsDataSource : AAPLBasicDataSource<AAPLCatSighting *>

- (instancetype)initWithCat:(AAPLCat *)cat NS_DESIGNATED_INITIALIZER;

@end
