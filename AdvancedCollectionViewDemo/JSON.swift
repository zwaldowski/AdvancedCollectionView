import Foundation

public enum JSON {
    public typealias Array = [AnyObject]
    public typealias Object = [String: AnyObject]
    
    case JSONString(String)
    case JSONArray(Array)
    case JSONObject(Object)
    case JSONDouble(Double)
    case JSONInt(Int)
    case JSONBool(Bool)
    case JSONNull
    
    public func value<A where A: JSONDecodable, A == A.DecodedType>() -> A? {
        return A.decode(self)
    }
    
    public mutating func setValue<A where A: JSONEncodable>(value: A!) {
        if value != nil {
            self = value.encode()
        } else {
            self = .JSONNull
        }
    }
    
}

// MARK: RawRepresentable

extension JSON: RawRepresentable {
    
    public init() {
        self = .JSONNull
    }
    
    public init(rawValue object: AnyObject!) {
        self = .JSONNull
        self.rawValue = object
    }
    
    public var rawValue: AnyObject! {
        get {
            switch self {
            case .JSONString(let str): return str
            case .JSONArray(let arr): return arr
            case .JSONObject(let obj): return obj
            case .JSONDouble(let double): return double
            case .JSONInt(let int): return int
            case .JSONBool(let bool): return bool
            case .JSONNull: return NSNull()
            }
        }
        set {
            switch newValue {
            case .Some(let string as String):
                self = .JSONString(string)
            case .Some(let array as [AnyObject]):
                self = .JSONArray(array)
            case .Some(let dict as [String: AnyObject]):
                self = .JSONObject(dict)
            case .Some(let number as NSNumber):
                switch number {
                case _ where CFNumberIsFloatType(number) != 0:
                    self = .JSONDouble(number.doubleValue)
                case _ where CFNumberGetType(number) == .CharType || CFGetTypeID(number) == CFBooleanGetTypeID():
                    self = .JSONBool(number.boolValue)
                default:
                    self = .JSONInt(number.integerValue)
                }
            default:
                self = .JSONNull
            }
        }
    }
    
}

// MARK: JSON Writeable

extension JSON {
    
    public init(data: NSData, options opt: NSJSONReadingOptions = .AllowFragments) {
        self.init(rawValue: NSJSONSerialization.JSONObjectWithData(data, options: opt, error: nil))
    }
    
    public func rawData(options opt: NSJSONWritingOptions = nil) -> NSData? {
        return NSJSONSerialization.dataWithJSONObject(rawValue, options: opt, error: nil)
    }
    
    public func rawString(encoding: UInt = NSUTF8StringEncoding, options opt: NSJSONWritingOptions = NSJSONWritingOptions.PrettyPrinted) -> String? {
        switch self {
        case .JSONString(let str): return str
        case .JSONDouble(let double): return toString(double)
        case .JSONInt(let int): return toString(int)
        case .JSONBool(let bool): return toString(bool)
        case .JSONNull: return "null"
        default:
            if let data = rawData(options: opt) {
                return NSString(data: data, encoding: encoding) as? String
            }
            return nil
        }
    }
    
}

//MARK: Comparable

public func ==(lhs: JSON, rhs: JSON) -> Bool {
    switch (lhs, rhs) {
    case (.JSONString(let lstr), .JSONString(let rstr)):
        return lstr == rstr
    case (.JSONArray(let larr), .JSONArray(let rarr)):
        return (larr as NSArray) == (rarr as NSArray)
    case (.JSONObject(let ldict), .JSONObject(let rdict)):
        return (ldict as NSDictionary) == (rdict as NSDictionary)
    case (.JSONDouble(let ldbl), .JSONDouble(let rdbl)):
        return ldbl == rdbl
    case (.JSONDouble(let ldbl), .JSONInt(let rint)):
        return ldbl == Double(rint)
    case (.JSONInt(let lint), .JSONInt(let rint)):
        return lint == rint
    case (.JSONInt(let lint), .JSONDouble(let rdbl)):
        return Double(lint) == rdbl
    case (.JSONBool(false), .JSONBool(false)), (.JSONBool(true), .JSONBool(true)), (.JSONNull, .JSONNull):
        return true
    default:
        return false
    }
}

public func <(lhs: JSON, rhs: JSON) -> Bool {
    switch (lhs, rhs) {
    case (.JSONString(let lstr), .JSONString(let rstr)):
        return lstr < rstr
    case (.JSONDouble(let ldbl), .JSONDouble(let rdbl)):
        return ldbl < rdbl
    case (.JSONDouble(let ldbl), .JSONInt(let rint)):
        return ldbl < Double(rint)
    case (.JSONInt(let lint), .JSONInt(let rint)):
        return lint < rint
    case (.JSONInt(let lint), .JSONDouble(let rdbl)):
        return Double(lint) < rdbl
    case (.JSONBool(false), .JSONBool(true)):
        return true
    default:
        return false
    }
}

extension JSON: Comparable {}

// MARK: Hashable

extension JSON: Hashable {
    
    public var hashValue: Int {
        switch self {
        case .JSONString(let string): return string.hashValue
        case .JSONDouble(let double): return double.hashValue
        case .JSONInt(let int): return int.hashValue
        case .JSONBool(let bool): return bool.hashValue
        default: return (rawValue as! NSObject).hash
        }
    }
    
}

// MARK: Printable

extension JSON: Printable {
    
    public var description: String {
        return rawString() ?? "unknown"
    }
    
}

// MARK: CollectionType

private enum JSONIndexStorage {
    case Array(JSON.Array.Index)
    case Object(JSON.Object.Index)
    case Identity
}

public struct JSONIndex: ForwardIndexType, Comparable {
    
    private let storage: JSONIndexStorage
    private init(_ storage: JSONIndexStorage) {
        self.storage = storage
    }
    
    private func successorStorage() -> JSONIndexStorage {
        switch storage {
        case .Array(let idx):
            return .Array(idx.successor())
        case .Object(let idx):
            return .Object(idx.successor())
        case .Identity:
            return .Identity
        }
    }
    
    public func successor() -> JSONIndex {
        return JSONIndex(successorStorage())
    }
    
}

public func <(lhs: JSONIndex, rhs: JSONIndex) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.Array(let lidx), .Array(let ridx)):
        return lidx < ridx
    case (.Object(let lidx), .Object(let ridx)):
        return lidx < ridx
    default:
        return false
    }
}

public func ==(lhs: JSONIndex, rhs: JSONIndex) -> Bool {
    switch (lhs.storage, rhs.storage) {
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
    
    public var isEmpty: Bool {
        switch self {
        case .JSONArray(let arr):
            return arr.isEmpty
        case .JSONObject(let dict):
            return dict.isEmpty
        case .JSONNull:
            return true
        default:
            return false
        }
    }
    
    public var count: Int {
        switch self {
        case .JSONArray(let arr):
            return arr.count
        case .JSONObject(let dict):
            return dict.count
        case .JSONNull:
            return 0
        default:
            return 1
        }
    }
    
    private var startIndexStorage: JSONIndexStorage {
        switch self {
        case .JSONArray(let arr):
            return .Array(arr.startIndex)
        case .JSONObject(let dict):
            return .Object(dict.startIndex)
        default:
            return .Identity
        }
    }
    
    public var startIndex: JSONIndex {
        return JSONIndex(startIndexStorage)
    }
    
    private var endIndexStorage: JSONIndexStorage {
        switch self {
        case .JSONArray(let arr):
            return .Array(arr.endIndex)
        case .JSONObject(let dict):
            return .Object(dict.endIndex)
        default:
            return .Identity
        }
    }
    
    public var endIndex: JSONIndex {
        return JSONIndex(endIndexStorage)
    }
    
    public subscript(index: JSONIndex) -> JSON {
        get {
            switch (self, index.storage) {
            case (.JSONArray(let arr), .Array(let idx)):
                if idx != arr.endIndex {
                    return JSON(rawValue: arr[idx])
                }
                return nil
            case (.JSONObject(let dict), .Object(let idx)):
                if idx != dict.endIndex {
                    return JSON(rawValue: dict[idx].1)
                }
                return nil
            default:
                return self
            }
        }
        set {
            switch (self, index.storage) {
            case (.JSONArray(var arr), .Array(let idx)):
                if idx != arr.endIndex {
                    arr[idx] = newValue.rawValue
                } else {
                    arr.append(newValue.rawValue)
                }
                self = .JSONArray(arr)
            case (.JSONObject(var dict), .Object(let idx)):
                if idx != dict.endIndex {
                    dict[dict[idx].0] = newValue.rawValue
                } else {
                    dict.removeAtIndex(idx)
                }
                self = .JSONObject(dict)
            default:
                self = newValue
            }
        }
    }
    
    public subscript(key: String) -> JSON! {
        get {
            switch (self) {
            case .JSONObject(let dict):
                return JSON(rawValue: dict[key])
            default:
                return self
            }
        }
        set {
            switch (self) {
            case .JSONObject(var dict):
                dict[key] = newValue.rawValue
                self = .JSONObject(dict)
            default: break
            }
        }
    }
    
    public subscript(index: Int) -> JSON {
        get {
            return self[JSONIndex(.Array(index))]
        }
        set {
            self[JSONIndex(.Array(index))] = newValue
        }
    }
    
    public func generate() -> GeneratorOf<JSON> {
        switch self {
        case .JSONArray(let arr):
            return GeneratorOf(lazy(arr).map {
                JSON(rawValue: $0)
                }.generate())
        case .JSONObject(let dict):
            return GeneratorOf(lazy(dict).map {
                JSON(rawValue: $0.1)
                }.generate())
        default:
            var incl = false
            return GeneratorOf {
                if incl { return nil }
                incl = true
                return self
            }
        }
    }
    
}

// MARK: Codecs

public protocol JSONDecodable {
    typealias DecodedType = Self
    static func decode(JSON) -> DecodedType?
}

public protocol JSONEncodable: JSONDecodable {
    func encode() -> JSON
}

// MARK: String

extension String: JSONEncodable {
    
    public static func decode(j: JSON) -> String? {
        switch j {
        case .JSONDouble, .JSONInt, .JSONBool, .JSONString:
            return j.description
        default:
            return nil
        }
    }
    
    public func encode() -> JSON {
        return .JSONString(self)
    }
    
}

extension JSON: StringLiteralConvertible {
    
    public init(stringLiteral value: StringLiteralType) {
        self = value.encode()
    }
    
    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self = value.encode()
    }
    
    public init(unicodeScalarLiteral value: StringLiteralType) {
        self = value.encode()
    }
    
}

// MARK: Array

extension JSON: ArrayLiteralConvertible {
    
    public init(arrayLiteral elements: AnyObject...) {
        self = .JSONArray(elements)
    }
    
    public func mapArray<A where A: JSONDecodable, A == A.DecodedType>() -> [A]? {
        switch self {
        case let .JSONArray(a):
            return a.reduce([]) {
                if let array = $0 {
                    let value = JSON(rawValue: $1)
                    let decoded = A.decode(value)
                    if let decoded = decoded {
                        return array + [decoded]
                    } else {
                        return .None
                    }
                } else {
                    return .None
                }
            }
        default: return .None
        }
    }
    
    public var array: [JSON]! {
        get {
            return rawArray.map { JSON(rawValue: $0) }
        }
        set {
            rawArray = newValue.map { $0.rawValue }
        }
    }
    
    public var rawArray: Array! {
        get {
            switch self {
            case .JSONArray(let array):
                return array
            default:
                return []
            }
        }
        set {
            if newValue != nil {
                self = .JSONArray(newValue)
            } else {
                self = .JSONNull
            }
        }
    }
    
}

// MARK: Object

extension JSON: DictionaryLiteralConvertible {
    
    public init(dictionaryLiteral elements: (String, AnyObject)...) {
        var dictionary = Object()
        for (key, value) in elements {
            dictionary[key] = value
        }
        self = .JSONObject(dictionary)
    }
    
    public func find(keys: [String]) -> JSON {
        return keys.reduce(self) { (value, key) in
            value[key]
        }
    }
    
    public var dictionary: [String: JSON]! {
        get {
            let raw = rawDictionary
            var result: [String: JSON] = Dictionary(minimumCapacity: raw.count)
            for (key, value) in raw {
                result[key] = JSON(rawValue: value)
            }
            return result
        }
        set {
            var raw = Object(minimumCapacity: newValue.count)
            for (key, value) in newValue {
                raw[key] = value.rawValue
            }
            rawDictionary = raw
            
        }
    }
    
    public var rawDictionary: Object! {
        get {
            switch self {
            case .JSONObject(let dict):
                return dict
            default:
                return [:]
            }
        }
        set {
            if newValue != nil {
                self = .JSONObject(newValue)
            } else {
                self = .JSONNull
            }
        }
    }
    
}

// MARK: Double

extension Double: JSONEncodable {
    
    public static func decode(j: JSON) -> Double? {
        switch j {
        case .JSONString(let string): return (string as NSString).doubleValue
        case .JSONDouble(let double): return double
        case .JSONInt(let int): return Double(int)
        case .JSONBool(let bool): return bool ? 1 : 0
        default: return 0
        }
    }
    
    public func encode() -> JSON {
        return .JSONDouble(self)
    }
    
}

extension JSON: FloatLiteralConvertible {
    
    public init(floatLiteral value: FloatLiteralType) {
        self = .JSONDouble(value)
    }
    
}

// MARK: Int

extension Int: JSONEncodable {
    
    public static func decode(j: JSON) -> Int? {
        switch j {
        case .JSONDouble(let double): return Int(double)
        case .JSONInt(let int): return int
        case .JSONBool(let bool): return bool ? 1 : 0
        case .JSONString(let string): return (string as NSString).integerValue
        default: return 0
        }
    }
    
    public func encode() -> JSON {
        return .JSONInt(self)
    }
    
}

extension JSON: IntegerLiteralConvertible {
    
    public init(integerLiteral value: IntegerLiteralType) {
        self = .JSONInt(value)
    }
    
}

// MARK: Bool

extension Bool: JSONEncodable {
    
    public static func decode(j: JSON) -> Bool? {
        switch j {
        case .JSONBool(let bool):
            return bool
        default:
            return false
        }
    }
    
    public func encode() -> JSON {
        return .JSONBool(self)
    }
    
}

extension JSON: BooleanLiteralConvertible {
    
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .JSONBool(value)
    }
    
}

// MARK: Nil

extension JSON: NilLiteralConvertible {
    
    public init(nilLiteral: ()) {
        self = .JSONNull
    }
    
}

// MARK: URL

extension NSURL: JSONEncodable {
    
    public class func decode(j: JSON) -> NSURL? {
        switch j {
        case .JSONString(let string):
            if let encoded = string.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) {
                return NSURL(string: encoded)
            }
            return nil
        default: return .None
        }
    }
    
    public func encode() -> JSON {
        return absoluteString.map { .JSONString($0) } ?? .JSONNull
    }
    
}



// MARK: Operators

infix operator <*> { associativity left }
infix operator <| { associativity left precedence 150 }
infix operator <|? { associativity left precedence 150 }
infix operator <|| { associativity left precedence 150 }
infix operator <||? { associativity left precedence 150 }

public func <*><A, B>(f: A -> B, a: A?) -> B? {
    switch a {
    case let .Some(x): return f(x)
    default: return .None
    }
}

public func <*><A, B>(f: (A -> B)?, a: A?) -> B? {
    switch f {
    case let .Some(fx): return fx <*> a
    default: return .None
    }
}

// MARK: Values

// Pull embedded value from JSON
public func <|<A where A: JSONDecodable, A == A.DecodedType>(json: JSON, keys: [String]) -> A? {
    return A.decode(json.find(keys))
}

// Pull value from JSON
public func <|<A where A: JSONDecodable, A == A.DecodedType>(json: JSON, key: String) -> A? {
    return json <| [key]
}

// Pull embedded optional value from JSON
public func <|?<A where A: JSONDecodable, A == A.DecodedType>(json: JSON, keys: [String]) -> A?? {
    return .Some(json <| keys)
}

// Pull optional value from JSON
public func <|?<A where A: JSONDecodable, A == A.DecodedType>(json: JSON, key: String) -> A?? {
    return json <|? [key]
}

// MARK: Arrays

// Pull embedded array from JSON
public func <||<A where A: JSONDecodable, A == A.DecodedType>(json: JSON, keys: [String]) -> [A]? {
    let value = json.find(keys)
    switch value {
    case .JSONNull:
        return nil
    default:
        return value.mapArray()
    }
}

// Pull array from JSON
public func <||<A where A: JSONDecodable, A == A.DecodedType>(json: JSON, key: String) -> [A]? {
    return json <|| [key]
}

// Pull embedded optional array from JSON
public func <||?<A where A: JSONDecodable, A == A.DecodedType>(json: JSON, keys: [String]) -> [A]?? {
    return .Some(json <|| keys)
}

// Pull optional array from JSON
public func <||?<A where A: JSONDecodable, A == A.DecodedType>(json: JSON, key: String) -> [A]?? {
    return json <||? [key]
}
