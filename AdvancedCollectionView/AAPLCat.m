/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Plain old data object for a cat. When the value of its favorite property changes, it sends a notification with the name AAPLCatFavoriteToggledNotificationName.
 */

#import "AAPLCat.h"

NSString * const AAPLCatFavoriteToggledNotificationName = @"AAPLCatFavoriteToggledNotificationName";

@implementation AAPLCat

static NSMapTable *AAPLAllCatsTable()
{
    static NSMapTable *allCats = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allCats = [NSMapTable strongToWeakObjectsMapTable];
    });

    return allCats;
}

+ (instancetype)catWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation
{
    NSMapTable *allCats = AAPLAllCatsTable();

    NSString *uniqueID = dictionaryRepresentation[@"uniqueID"];
    AAPLCat *cat = [allCats objectForKey:uniqueID];
    if (!cat)
        cat = [[self alloc] init];
    [cat updateWithDictionaryRepresentation:dictionaryRepresentation];
    [allCats setObject:cat forKey:uniqueID];

    return cat;
}

- (void)setFavorite:(BOOL)favorite
{
    if (_favorite == favorite)
        return;

    _favorite = favorite;

    // Let everyone know our favorite status has changed.
    [[NSNotificationCenter defaultCenter] postNotificationName:AAPLCatFavoriteToggledNotificationName object:self];
}

- (void)updateWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation
{
    NSString *uniqueID = dictionaryRepresentation[@"uniqueID"];
    if (uniqueID && !self.uniqueID)
        self.uniqueID = uniqueID;

    NSString *name = dictionaryRepresentation[@"name"];
    if (name)
        self.name = name;

    NSNumber *favorite = dictionaryRepresentation[@"favorite"];
    if (favorite)
        self.favorite = [favorite boolValue];

    NSString *shortDescription = dictionaryRepresentation[@"shortDescription"];
    if (shortDescription)
        self.shortDescription = shortDescription;

    NSString *conservationStatus = dictionaryRepresentation[@"conservationStatus"];
    if (conservationStatus)
        self.conservationStatus = conservationStatus;

    NSString *classificationKingdom = dictionaryRepresentation[@"kingdom"];
    if (classificationKingdom)
        self.classificationKingdom = classificationKingdom;

    NSString *classificationPhylum = dictionaryRepresentation[@"phylum"];
    if (classificationPhylum)
        self.classificationPhylum = classificationPhylum;

    NSString *classificationClass = dictionaryRepresentation[@"class"];
    if (classificationClass)
        self.classificationClass = classificationClass;

    NSString *classificationOrder = dictionaryRepresentation[@"order"];
    if (classificationOrder)
        self.classificationOrder = classificationOrder;

    NSString *classificationFamily = dictionaryRepresentation[@"family"];
    if (classificationFamily)
        self.classificationFamily = classificationFamily;

    NSString *classificationGenus = dictionaryRepresentation[@"genus"];
    if (classificationGenus)
        self.classificationGenus = classificationGenus;

    NSString *classificationSpecies = dictionaryRepresentation[@"species"];
    if (classificationSpecies)
        self.classificationSpecies = classificationSpecies;

    NSString *habitat = dictionaryRepresentation[@"habitat"];
    if (habitat)
        self.habitat = habitat;

    NSString *description = dictionaryRepresentation[@"description"];
    if (description)
        self.longDescription = description;
}

@end
