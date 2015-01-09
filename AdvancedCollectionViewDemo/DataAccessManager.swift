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
    
    private var sightingsCache = [String: [CatSighting]]()
    private var catsCache = [String: Cat]()
    
    private init() {}
    
    class var shared: DataAccessManager {
        return sharedDataAccessManager
    }
    
    private func fetchJSON(named name: String, completion: JSON -> ()) {
        let queue = dispatch_get_global_queue(0, 0)
        
        let finish = { (json: JSON, delay: NSTimeInterval?) -> () in
            let block = {
                completion(json)
            }
            
            if let delay = delay {
                let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
                dispatch_after(time, queue, block)
            } else {
                dispatch_async(queue, block)
            }
        }
        
        dispatch_async(queue) {
            if let URL = NSBundle(forClass: self.dynamicType).URLForResource(name, withExtension: "json") {
                if let data = NSData(contentsOfURL: URL, options: .DataReadingMappedIfSafe, error: nil) {
                    let obj = JSON(data: data, options: nil)
                    let result = obj["results"]
                    let delay: NSTimeInterval? = obj["delayResults"].value()
                    finish(result, delay)
                } else {
                    finish(nil, nil)
                }
            } else {
                finish(nil, nil)
            }
        }
    }
    
    func fetchCatList(#reversed: Bool, completion: [Cat]? -> ()) {
        fetchJSON(named: "CatList") { json in
            var cats: [Cat]? = json.mapArray()
            
            let cache = cats?.reduce([:]) { (var dict, cat) -> [String: Cat] in
                dict[cat.uniqueID] = cat
                return dict
            } ?? [:]
            
            let ctor = { (cat1: Cat, cat2: Cat) -> Bool in
                cat1.name.localizedCaseInsensitiveCompare(cat2.name) == .OrderedAscending
            }
            
            if reversed {
                cats?.sort { !ctor($0, $1) }
            } else {
                cats?.sort(ctor)
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                self.catsCache = cache
                self.sightingsCache.removeAll(keepCapacity: true)
                completion(cats)
            }
        }
    }
    
    func fetchDetail(#cat: Cat, completion: Cat? -> ()) {
        let resource = "detail-\(cat.uniqueID)"
        fetchJSON(named: resource) { json in
            let cat: Cat? = json.value()
                
            dispatch_async(dispatch_get_main_queue()) {
                if let cat = cat {
                    self.catsCache[cat.uniqueID] = cat
                }
                
                completion(cat)
            }
        }
    }
    
    func fetchSightings(#cat: Cat, completion: [CatSighting]? -> ()) {
        let key = cat.uniqueID
        if let existing = sightingsCache[key] {
            return completion(existing)
        }
        
        dispatch_async(dispatch_get_global_queue(0, 0)) {
            // Just make up some random sightings for this cat…
            let names = [ "Jani Izabella", "Billie Dilşad", "Kerensa Marita", "Noach Janetta", "Janele Tzion", "Phyliss Forest", "Roswell Wolfgang", "Meri Floella", "Minty Honor", "Afon Geoffrey" ]
            
            func random(#max: Int) -> Int {
                return Int(arc4random_uniform(UInt32(max)))
            }
            
            let numberOfNames = names.count
            let numberOfSightings = random(max: 20)
            let date = NSDate()
            let calendar = NSCalendar.currentCalendar()
            
            let sightings = lazy(0..<numberOfSightings).map { _ -> CatSighting in
                let dateComponents = NSDateComponents()
                dateComponents.day = -random(max: 60)
                dateComponents.minute = -random(max: 60*24)
                
                let date = calendar.dateByAddingComponents(dateComponents, toDate: NSDate(), options: nil)!
                let catFancier = names[random(max: names.count)]
                let description = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
                
                return CatSighting(date: date, catFancier: catFancier, shortDescription: description)
            }.array
            
            let time = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC)))
            dispatch_after(time, dispatch_get_main_queue()) {
                self.sightingsCache[key] = sightings
                completion(sightings)
            }
        }
    }
    
}
