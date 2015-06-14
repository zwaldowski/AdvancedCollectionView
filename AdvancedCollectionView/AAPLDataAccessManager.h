/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A make believe data access layer. In real life this would talk to core data or a server.
 */

@import Foundation;

@class AAPLCat, AAPLCatSighting;

@interface AAPLDataAccessManager : NSObject

+ (AAPLDataAccessManager *)manager;

- (void)fetchCatListWithCompletionHandler:(void(^)(NSArray<AAPLCat *> *cats, NSError *error))handler;
- (void)fetchFavoriteCatListWithCompletionHandler:(void(^)(NSArray<AAPLCat *> *cats, NSError *error))handler;
- (void)fetchDetailForCat:(AAPLCat *)cat completionHandler:(void(^)(AAPLCat *cat, NSError *error))handler;
- (void)fetchSightingsForCat:(AAPLCat *)cat completionHandler:(void(^)(NSArray<AAPLCatSighting *> *sightings, NSError *error))handler;

@end
