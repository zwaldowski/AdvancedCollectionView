/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A make believe data access layer. In real life this would talk to core data or a server.
 */

@import AdvancedCollectionView;

@class AAPLCat, AAPLCatSighting;

@interface AAPLDataAccessManager : NSObject

+ (AAPLDataAccessManager *)manager;

- (void)fetchCatListWithCompletionHandler:(void(^)(AAPLGeneric(NSArray, AAPLCat *) *cats, NSError *error))handler;
- (void)fetchFavoriteCatListWithCompletionHandler:(void(^)(AAPLGeneric(NSArray, AAPLCat *) *cats, NSError *error))handler;
- (void)fetchDetailForCat:(AAPLCat *)cat completionHandler:(void(^)(AAPLCat *cat, NSError *error))handler;
- (void)fetchSightingsForCat:(AAPLCat *)cat completionHandler:(void(^)(AAPLGeneric(NSArray, AAPLCatSighting *) *sightings, NSError *error))handler;

@end
