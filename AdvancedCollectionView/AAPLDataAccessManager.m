/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A make believe data access layer. In real life this would talk to core data or a server.
 */

#import "AAPLDataAccessManager.h"
#import "AAPLCat.h"
#import "AAPLCatSighting.h"

@interface AAPLDataAccessManager ()
@property (nonatomic, strong) NSCache *sightingsCache;
@property (nonatomic, strong) NSArray *favoriteCats;
@end

@implementation AAPLDataAccessManager

+ (AAPLDataAccessManager *)manager
{
    static AAPLDataAccessManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[AAPLDataAccessManager alloc] init];
    });

    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.favoriteCats = @[];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeFavoriteToggledNotification:) name:AAPLCatFavoriteToggledNotificationName object:nil];

    return self;
}

- (void)observeFavoriteToggledNotification:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AAPLCat *cat = notification.object;
        NSMutableArray *favoriteCats = [self.favoriteCats mutableCopy];
        NSUInteger position = [favoriteCats indexOfObject:cat];

        if (cat.favorite) {
            if (NSNotFound == position)
                [favoriteCats addObject:cat];
        }
        else {
            if (NSNotFound != position)
                [favoriteCats removeObjectAtIndex:position];
        }

        self.favoriteCats = [NSArray arrayWithArray:favoriteCats];
    });
}

- (void)fetchJSONResourceWithName:(NSString *)name completionHandler:(void(^)(NSDictionary *json, NSError *error))handler
{
    NSParameterAssert(handler != nil);

    NSURL *resourceURL = [[NSBundle mainBundle] URLForResource:name withExtension:@"json"];
    if (!resourceURL) {
        // Should create an NSError and pass it to the completion handler
        NSAssert(NO, @"Could not find resource: %@", name);
    }

    NSError *error;

    // Fetch the json data. If there's an error, call the handler and return.
    NSData *jsonData = [NSData dataWithContentsOfURL:resourceURL options:NSDataReadingMappedIfSafe error:&error];
    if (!jsonData) {
        handler(nil, error);
        return;
    }

    // Parse the json data. If there's an error parsing the json data, call the handler and return.
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (!json) {
        handler(nil, error);
        return;
    }

    // If the json data specified that we should delay the results, do so before calling the handler
    NSNumber *delayResults = json[@"delayResults"];
    if (delayResults && [delayResults isKindOfClass:[NSNumber class]]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([delayResults floatValue] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            handler(json, nil);
        });
    }
    else {
        handler(json, nil);
    }
}

- (void)fetchCatListWithCompletionHandler:(void(^)(NSArray<AAPLCat *> *cats, NSError *error))handler
{
    [self fetchJSONResourceWithName:@"CatList" completionHandler:^(NSDictionary *json, NSError *error) {
        if (error) {
            if (handler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(nil, error);
                });
            }
            return;
        }

        NSArray *results = json[@"results"];
        NSAssert([results isKindOfClass:[NSArray class]], @"results property should be an array of cats");

        NSMutableArray *cats = [NSMutableArray array];
        for (NSDictionary *catDictionary in results) {
            AAPLCat *cat = [AAPLCat catWithDictionaryRepresentation:catDictionary];
            if (!cat)
                continue;
            [cats addObject:cat];
        }

        [cats sortUsingComparator:^(AAPLCat *cat1, AAPLCat *cat2) {
            return [cat1.name localizedCaseInsensitiveCompare:cat2.name];
        }];

        if (handler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(cats, nil);
            });
        }
    }];
}

- (void)fetchFavoriteCatListWithCompletionHandler:(void(^)(NSArray<AAPLCat *> *cats, NSError *error))handler
{
    if (handler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(self.favoriteCats, nil);
        });
    }
}

- (void)fetchDetailForCat:(AAPLCat *)cat completionHandler:(void (^)(AAPLCat *, NSError *))handler
{
    NSParameterAssert(cat != nil);

    NSString *resourceName = [NSString stringWithFormat:@"detail-%@", cat.uniqueID];

    [self fetchJSONResourceWithName:resourceName completionHandler:^(NSDictionary *json, NSError *error) {
        if (error) {
            if (handler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(nil, error);
                });
            }
            return;
        }

        NSDictionary *results = json[@"results"];
        NSAssert([results isKindOfClass:[NSDictionary class]], @"results property should be a dictionary with a cat detail");

        [cat updateWithDictionaryRepresentation:results];
        if (handler)
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(cat, nil);
            });
    }];
}

- (void)fetchSightingsForCat:(AAPLCat *)cat completionHandler:(void (^)(NSArray<AAPLCatSighting *> *, NSError *))handler
{
    NSParameterAssert(cat != nil);

    if (!self.sightingsCache)
        self.sightingsCache = [[NSCache alloc] init];

    NSArray *cachedSightings = [self.sightingsCache objectForKey:cat.uniqueID];
    if (cachedSightings) {
        if (handler)
            handler(cachedSightings, nil);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Just make up some random sightings for this cat…
        NSArray *names = @[@"Jani Izabella", @"Billie Dilşad", @"Kerensa Marita", @"Noach Janetta", @"Janele Tzion", @"Phyliss Forest", @"Roswell Wolfgang", @"Meri Floella", @"Minty Honor", @"Afon Geoffrey"];

        int numberOfNames = (int)[names count];
        int numberOfSightings = arc4random_uniform(20);

        NSDate *date = [NSDate date];
        NSCalendar *calendar = [NSCalendar currentCalendar];

        NSMutableArray *sightings = [NSMutableArray arrayWithCapacity:numberOfSightings];

        for (int sightingIndex =0; sightingIndex < numberOfSightings; ++sightingIndex) {
            AAPLCatSighting *sighting = [[AAPLCatSighting alloc] init];
            NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
            dateComponents.day = -arc4random_uniform(60);
            dateComponents.minute = -arc4random_uniform(60*24);

            sighting.date = date = [calendar dateByAddingComponents:dateComponents toDate:date options:0];
            sighting.catFancier = names[arc4random_uniform(numberOfNames)];
            sighting.shortDescription = @"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";

            [sightings addObject:sighting];
        }

        [self.sightingsCache setObject:sightings forKey:cat.uniqueID];

        if (handler)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                handler(sightings, nil);
            });
    });
}

@end
