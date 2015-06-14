/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A basic data source that either fetches the list of all available cats or the user's favorite cats. If this data source represents the favorites, it listens for a notification with the name AAPLCatFavoriteToggledNotificationName and will update itself appropriately.
 */

#import "AAPLBasicDataSource.h"
@class AAPLCat;

@interface AAPLCatListDataSource : AAPLBasicDataSource<AAPLCat *>
/// Is this list showing the favorites or all available cats?
@property (nonatomic) BOOL showingFavorites;
@end
