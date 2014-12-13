/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Plain old data object for a cat. When the value of its favorite property changes, it sends a notification with the name AAPLCatFavoriteToggledNotificationName.
  
 */

@import Foundation;

extern NSString * const AAPLCatFavoriteToggledNotificationName;

@interface AAPLCat : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *uniqueID;
@property (nonatomic, strong) NSString *shortDescription;
@property (nonatomic, strong) NSString *conservationStatus;
@property (nonatomic, strong) NSString *classificationKingdom;
@property (nonatomic, strong) NSString *classificationPhylum;
@property (nonatomic, strong) NSString *classificationClass;
@property (nonatomic, strong) NSString *classificationOrder;
@property (nonatomic, strong) NSString *classificationFamily;
@property (nonatomic, strong) NSString *classificationGenus;
@property (nonatomic, strong) NSString *classificationSpecies;
@property (nonatomic, strong) NSString *habitat;
@property (nonatomic, strong) NSString *longDescription;

@property (nonatomic, getter=isFavorite) BOOL favorite;

- (void)updateWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;

+ (instancetype)catWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;

@end
