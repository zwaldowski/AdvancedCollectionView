/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Plain old data object for a cat.
  
 */

@import Foundation;

@interface AAPLCat : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *uniqueID;
@property (nonatomic, copy) NSString *shortDescription;
@property (nonatomic, copy) NSString *conservationStatus;
@property (nonatomic, copy) NSString *classificationKingdom;
@property (nonatomic, copy) NSString *classificationPhylum;
@property (nonatomic, copy) NSString *classificationClass;
@property (nonatomic, copy) NSString *classificationOrder;
@property (nonatomic, copy) NSString *classificationFamily;
@property (nonatomic, copy) NSString *classificationGenus;
@property (nonatomic, copy) NSString *classificationSpecies;
@property (nonatomic, copy) NSString *habitat;
@property (nonatomic, copy) NSString *longDescription;

- (void)updateWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;

+ (instancetype)catWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;

@end
