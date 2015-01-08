//
//  JSON.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/8/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import Foundation

public enum JSON {
    public typealias JSONArray = [AnyObject]
    public typealias JSONObject = [Swift.String: AnyObject]
    
    case Double(Swift.Double)
    case Int(Swift.Int)
    case Bool(Swift.Bool)
    case String(Swift.String)
    case Array(JSONArray)
    case Object(JSONObject)
    case Null
}

// MARK: RawRepresentable

extension JSON: RawRepresentable {
    
    public init() {
        self = .Null
    }
    
    public init!(rawValue object: AnyObject!) {
        self = .Null
        self.rawValue = object
    }
    
    public var rawValue: AnyObject! {
        get {
            switch self {
            case .Double(let double): return double
            case .Int(let int): return int
            case .Bool(let bool): return bool
            case .String(let str): return str
            case .Array(let arr): return arr
            case .Object(let obj): return obj
            case .Null: return NSNull()
            }
        }
        set {
            switch newValue {
            case .Some(let number as NSNumber) where CFNumberIsFloatType(number) != 0:
                self = .Double(number.doubleValue)
            case .Some(let number as NSNumber) where CFNumberGetType(number) == .CharType || CFGetTypeID(number) == CFBooleanGetTypeID():
                self = .Bool(number.boolValue)
            case .Some(let number as NSNumber):
                self = .Int(number.integerValue)
            case .Some(let string as NSString):
                self = .String(string)
            case .Some(let array as [AnyObject]):
                self = .Array(array)
            case .Some(let dict as [Swift.String: AnyObject]):
                self = .Object(dict)
            default:
                self = .Null
            }
        }
    }
    
}

// MARK: JSON Writeable

extension JSON {
    
    public static func fromRawData(data: NSData, options opt: NSJSONReadingOptions = .AllowFragments) -> Result<JSON> {
        var error: NSError?
        if let dict: AnyObject = NSJSONSerialization.JSONObjectWithData(data, options: opt, error: &error) {
            return success(JSON(rawValue: dict))
        } else {
            return failure(error!)
        }
    }
    
    public func rawData(options opt: NSJSONWritingOptions = nil) -> Result<NSData> {
        var error: NSError?
        if let data = NSJSONSerialization.dataWithJSONObject(rawValue, options: opt, error: &error) {
            return success(data)
        } else {
            return failure(error!)
        }
    }
    
    public func rawString(encoding: UInt = NSUTF8StringEncoding, options opt: NSJSONWritingOptions = NSJSONWritingOptions.PrettyPrinted) -> Swift.String? {
        switch self {
        case .Double(let double): return toString(double)
        case .Int(let int): return toString(int)
        case .Bool(let bool): return toString(bool)
        case .String(let str): return str
        case .Null: return "null"
        default:
            switch rawData(options: opt) {
            case .Success(let box):
                return NSString(data: box.unbox, encoding: encoding)
            case .Failure:
                return nil
            }
        }
    }
    
}

//MARK: Comparable

extension JSON: Comparable {}

public func ==(lhs: JSON, rhs: JSON) -> Bool {
    switch (lhs, rhs) {
    case (.Double(let ldbl), .Double(let rdbl)):
        return ldbl == rdbl
    case (.Int(let lint), .Int(let rint)):
        return lint == rint
    case (.Double(let ldbl), .Int(let rint)):
        return ldbl == Double(rint)
    case (.Int(let lint), .Double(let rdbl)):
        return Double(lint) == rdbl
    case (.Bool(false), .Bool(false)), (.Bool(true), .Bool(true)), (.Null, .Null):
        return true
    case (.String(let lstr), .String(let rstr)):
        return lstr == rstr
    case (.Array(let larr), .Array(let rarr)):
        return (larr as NSArray) == (rarr as NSArray)
    case (.Object(let ldict), .Object(let rdict)):
        return (ldict as NSDictionary) == (rdict as NSDictionary)
    default:
        return false
    }
}

public func <(lhs: JSON, rhs: JSON) -> Bool {
    switch (lhs, rhs) {
    case (.Double(let ldbl), .Double(let rdbl)):
        return ldbl < rdbl
    case (.Int(let lint), .Int(let rint)):
        return lint < rint
    case (.Double(let ldbl), .Int(let rint)):
        return ldbl < Double(rint)
    case (.Int(let lint), .Double(let rdbl)):
        return Double(lint) < rdbl
    case (.Bool(false), .Bool(true)):
        return true
    case (.String(let lstr), .String(let rstr)):
        return lstr < rstr
    default:
        return false
    }
}

// MARK: Hashable

extension JSON: Hashable {
    
    public var hashValue: Swift.Int {
        switch self {
        case .Double(let double): return double.hashValue
        case .Int(let int): return int.hashValue
        case .Bool(let bool): return bool.hashValue
        case .String(let string): return string.hashValue
        default: return (rawValue as NSObject).hash
        }
    }
    
}

// MARK: Printable

extension JSON: Printable {
    
    public var description: Swift.String {
        return rawString() ?? "unknown"
    }
    
}

// MARK: CollectionType

public enum JSONIndex: BidirectionalIndexType, Comparable {
    case Array(JSON.JSONArray.Index)
    case Object(JSON.JSONObject.Index)
    case Identity
    
    public func predecessor() -> JSONIndex {
        switch self {
        case .Array(let idx):
            return .Array(idx.predecessor())
        case .Object(let idx):
            return .Object(idx.predecessor())
        case .Identity:
            return .Identity
        }
    }
    
    public func successor() -> JSONIndex {
        switch self {
        case .Array(let idx):
            return .Array(idx.predecessor())
        case .Object(let idx):
            return .Object(idx.predecessor())
        case .Identity:
            return .Identity
        }
    }
    
}

public func <(lhs: JSONIndex, rhs: JSONIndex) -> Bool {
    switch (lhs, rhs) {
    case (.Array(let lidx), .Array(let ridx)):
        return lidx < ridx
    case (.Object(let lidx), .Object(let ridx)):
        return lidx < ridx
    default:
        return false
    }
}

public func ==(lhs: JSONIndex, rhs: JSONIndex) -> Bool {
    switch (lhs, rhs) {
    case (.Array(let lidx), .Array(let ridx)):
        return lidx == ridx
    case (.Object(let lidx), .Object(let ridx)):
        return lidx == ridx
    case (.Identity, .Identity):
        return true
    default:
        return false
    }
}

extension JSON: CollectionType {
    
    public var isEmpty: Swift.Bool {
        switch self {
        case .Array(let arr):
            return arr.isEmpty
        case .Object(let dict):
            return dict.isEmpty
        case .Null:
            return true
        default:
            return false
        }
    }
    
    public var count: Swift.Int {
        switch self {
        case .Array(let arr):
            return arr.count
        case .Object(let dict):
            return dict.count
        case .Null:
            return 0
        default:
            return 1
        }
    }
    
    public var startIndex: JSONIndex {
        switch self {
        case .Array(let arr):
            return .Array(arr.startIndex)
        case .Object(let dict):
            return .Object(dict.startIndex)
        default:
            return .Identity
        }
    }
    
    public var endIndex: JSONIndex {
        switch self {
        case .Array(let arr):
            return .Array(arr.endIndex)
        case .Object(let dict):
            return .Object(dict.endIndex)
        default:
            return .Identity
        }
    }
    
    public subscript(index: JSONIndex) -> JSON {
        get {
            switch (self, index) {
            case (.Array(let arr), .Array(let idx)):
                if idx != arr.endIndex {
                    return JSON(rawValue: arr[idx])
                }
                return nil
            case (.Object(let dict), .Object(let idx)):
                if idx != dict.endIndex {
                    return JSON(rawValue: dict[idx].1)
                }
                return nil
            default:
                return self
            }
        }
        set {
            switch (self, index) {
            case (.Array(var arr), .Array(let idx)):
                if idx != arr.endIndex {
                    arr[idx] = newValue.rawValue
                } else {
                    arr.append(newValue.rawValue)
                }
                self = .Array(arr)
            case (.Object(var dict), .Object(let idx)):
                if idx != dict.endIndex {
                    dict[dict[idx].0] = newValue.rawValue
                } else {
                    dict.removeAtIndex(idx)
                }
                self = .Object(dict)
            default:
                self = newValue
            }
        }
    }
    
    public subscript(key: Swift.String) -> JSON! {
        get {
            switch (self) {
            case .Object(let dict):
                return JSON(rawValue: dict[key])
            default:
                return self
            }
        }
        set {
            switch (self) {
            case .Object(var dict):
                dict[key] = newValue.rawValue
                self = .Object(dict)
            default: break
            }
        }
    }
    
    public subscript(index: Swift.Int) -> JSON {
        get {
            return self[.Array(index)]
        }
    }
    
    public func generate() -> GeneratorOf<JSON> {
        switch self {
        case .Array(let arr):
            return GeneratorOf(lazy(arr).map {
                JSON(rawValue: $0)!
                }.generate())
        case .Object(let dict):
            return GeneratorOf(lazy(dict).map {
                JSON(rawValue: $0.1)!
                }.generate())
        default:
            var incl = false
            return GeneratorOf {
                if incl {
                    return nil
                }
                incl = true
                return self
            }
        }
    }
    
}

// MARK: Double

extension JSON: FloatLiteralConvertible {
    
    public init(floatLiteral value: FloatLiteralType) {
        self = .Double(value)
    }
    
    public var double: Swift.Double! {
        get {
            switch self {
            case .Double(let double): return double
            case .Int(let int): return Swift.Double(int)
            case .Bool(let bool): return bool ? 1 : 0
            case .String(let string): return (string as NSString).doubleValue
            default: return 0
            }
        }
        set {
            if newValue != nil {
                self = .Double(newValue)
            } else {
                self = nil
            }
        }
    }
    
}

// MARK: Int

extension JSON: IntegerLiteralConvertible {
    
    public init(integerLiteral value: IntegerLiteralType) {
        self = .Int(value)
    }
    
    public var int: Swift.Int! {
        get {
            switch self {
            case .Double(let double): return Swift.Int(double)
            case .Int(let int): return int
            case .Bool(let bool): return bool ? 1 : 0
            case .String(let string): return (string as NSString).integerValue
            default: return 0
            }
        }
        set {
            if newValue != nil {
                self = .Int(newValue)
            } else {
                self = nil
            }
        }
    }
    
}

// MARK: Bool

extension JSON: BooleanLiteralConvertible {
    
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .Bool(value)
    }
    
    public var bool: Swift.Bool! {
        get {
            switch self {
            case .Bool(let bool):
                return bool
            default:
                return false
            }
        }
        set {
            if newValue != nil {
                self = .Bool(newValue)
            } else {
                self = .Null
            }
        }
    }
    
}

// MARK: String

extension JSON: StringLiteralConvertible {
    
    public init(stringLiteral value: StringLiteralType) {
        self = .String(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self = .String(value)
    }
    
    public init(unicodeScalarLiteral value: StringLiteralType) {
        self = .String(value)
    }
    
    public var string: Swift.String! {
        get {
            switch self {
            case .Double, .Int, .Bool, .String:
                return description
            default:
                return ""
            }
        }
        set {
            if newValue != nil {
                self = .String(newValue)
            } else {
                self = .Null
            }
        }
    }
    
}

// MARK: Array

extension JSON: ArrayLiteralConvertible {
    
    public init(arrayLiteral elements: AnyObject...) {
        self = .Array(elements)
    }
    
    public var array: [JSON]! {
        get {
            return rawArray.map { JSON(rawValue: $0)! }
        }
        set {
            rawArray = newValue.map { $0.rawValue }
        }
    }
    
    public var rawArray: JSONArray! {
        get {
            switch self {
            case .Array(let array):
                return array
            default:
                return []
            }
        }
        set {
            if newValue != nil {
                self = .Array(newValue)
            } else {
                self = .Null
            }
        }
    }
    
}

// MARK: Object

extension JSON: DictionaryLiteralConvertible {
    
    public init(dictionaryLiteral elements: (Swift.String, AnyObject)...) {
        var dictionary = JSONObject()
        for (key, value) in elements {
            dictionary[key] = value
        }
        self = .Object(dictionary)
    }
    
    public var dictionary: [Swift.String: JSON]! {
        get {
            let raw = rawDictionary
            var result: [Swift.String: JSON] = Dictionary(minimumCapacity: raw.count)
            for (key, value) in raw {
                result[key] = JSON(rawValue: value)
            }
            return result
        }
        set {
            var raw = JSONObject(minimumCapacity: newValue.count)
            for (key, value) in newValue {
                raw[key] = value.rawValue
            }
            rawDictionary = raw
            
        }
    }
    
    public var rawDictionary: JSONObject! {
        get {
            switch self {
            case .Object(let dict):
                return dict
            default:
                return [:]
            }
        }
        set {
            if newValue != nil {
                self = .Object(newValue)
            } else {
                self = .Null
            }
        }
    }
    
}

// MARK: Nil

extension JSON: NilLiteralConvertible {
    
    public init(nilLiteral: ()) {
        self = .Null
    }
    
}

// MARK: URL

extension JSON {
    
    public var URL: NSURL? {
        get {
            switch self {
            case .String(let string):
                if let encoded = string.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) {
                    return NSURL(string: encoded)
                }
                return nil
            default:
                return nil
            }
        }
        set {
            self = newValue?.absoluteString.map { .String($0) } ?? .Null
        }
    }
}
