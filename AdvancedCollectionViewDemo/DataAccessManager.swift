//
//  DataAccessManager.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/8/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import Foundation

private let sharedDataAccessManager = DataAccessManager()

final class DataAccessManager {
    
    private let sightingsCache = NSCache()
    private var catsCache = [String: Cat]()
    
    private init() {}
    
    class var shared: DataAccessManager {
        return sharedDataAccessManager
    }
    
    private func fetchJSON(named name: String, completion: Result<JSON> -> ()) {
        let URL = NSBundle(forClass: self.dynamicType).URLForResource(name, withExtension: "json")!
        var error: NSError?
        if let data = NSData(contentsOfURL: URL, options: .DataReadingMappedIfSafe, error: &error) {
            let obj = JSON.fromRawData(data)
            switch obj {
                
            }
        } else {
            completion(failure(error!))
        }
        
    }
    
    /*
    

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
    */
    
    func fetchCatList(#reversed: Bool, completion: ([Cat]?, NSError?) -> ()) {
        
    }
    
    func fetchDetail(#cat: Cat, completion: (Cat?, NSError?) -> ()) {
        
    }
    
    func fetchSightings(#cat: Cat, completion: (Cat?, NSError?) -> ()) {
        
    }
    
}