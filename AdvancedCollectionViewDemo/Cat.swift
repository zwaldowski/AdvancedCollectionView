//
//  Cat.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/8/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

struct Classification {
    let kingdom: String
    let phylum: String
    let subclass: String
    let order: String
    let family: String
    let genus: String
    let species: String
}

struct Cat {
    let name: String
    let uniqueID: String
    let shortDescription: String
    let conservationStatus: String?
    let habitat: String?
    let longDescription: String?
    let classification: Classification?
}

func ==(lhs: Cat, rhs: Cat) -> Bool {
    return lhs.uniqueID == rhs.uniqueID
}

extension Cat: Hashable {
    
    var hashValue: Int {
        return uniqueID.hash
    }
    
}

extension Classification: JSONDecodable {
    
    static func create(kingdom: String)(phylum: String)(subclass: String)(order: String)(family: String)(genus: String)(species: String) -> Classification {
        return Classification(kingdom: kingdom, phylum: phylum, subclass: subclass, order: order, family: family, genus: genus, species: species)
    }
    
    static func decode(j: JSON) -> Classification? {
        return create
            <*> j <| "kingdom"
            <*> j <| "phylum"
            <*> j <| "class"
            <*> j <| "order"
            <*> j <| "family"
            <*> j <| "genus"
            <*> j <| "species"
    }
    
}

extension Cat: JSONDecodable {
    
    static func create(name: String)(uniqueID: String)(shortDescription: String)(conservationStatus: String?)(habitat: String?)(longDescription: String?)(classification: Classification?) -> Cat {
        return Cat(name: name, uniqueID: uniqueID, shortDescription: shortDescription, conservationStatus: conservationStatus, habitat: habitat, longDescription: longDescription, classification: classification)
    }
    
    static func decode(j: JSON) -> Cat? {
        let f = create
            <*> j <| "name"
            <*> j <| "uniqueID"
            <*> j <| "shortDescription"
            <*> j <|? "conservationStatus"
            <*> j <|? "habitat"
            <*> j <|? "description"
            <*> j <|? []
        return f
    }
    
}
