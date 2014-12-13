/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A plain old data object for a cat sighting.
  
 */

@import Foundation;

@interface AAPLCatSighting : NSObject
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSString *catFancier;
@property (nonatomic, strong) NSString *shortDescription;
@end
