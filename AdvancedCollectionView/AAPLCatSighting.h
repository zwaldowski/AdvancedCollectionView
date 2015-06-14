/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A plain old data object for a cat sighting.
 */

@import Foundation;

@interface AAPLCatSighting : NSObject
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *catFancier;
@property (nonatomic, copy) NSString *shortDescription;
@end
