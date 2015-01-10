/// A set of unique elements as determined by `hashValue` and `==`.
public struct Set<T: Hashable> {
    
    private typealias Dictionary = [T: Unit]
    
    /// The underlying dictionary.
    private var values: Dictionary
    
    /// Constructs a `Set` with a dictionary of `values`.
    private init(values: Dictionary) {
        self.values = values
    }
    
    // MARK: Properties
    
    public var count: Int {
        return values.count
    }
    
    public var isEmpty: Bool {
        return values.isEmpty
    }
    
}

// MARK: Constructors

extension Set {
    
    public init() {
        self.init(values: [:])
    }
    
    public init(minimumCapacity: Int) {
        self.init(values: Dictionary(minimumCapacity: minimumCapacity))
    }
    
    public init<S: SequenceType where S.Generator.Element == T>(_ sequence: S) {
        self.init()
        extend(sequence)
    }
    
    public init(_ elements: T...) {
        self.init(elements)
    }
    
}

// MARK: SequenceType

extension Set: SequenceType {
    
    public func generate() -> GeneratorOf<T> {
        return GeneratorOf(values.keys.generate())
    }
    
}

// MARK: - CollectionType

extension Set: CollectionType {
    
    public var startIndex: SetIndex<T> { return SetIndex(values.startIndex) }
    public var endIndex: SetIndex<T> { return SetIndex(values.endIndex) }
    
    public subscript(v: ()) -> T {
        get { return values[values.startIndex].0 }
        set { insert(newValue) }
    }
    
    public subscript(index: SetIndex<T>) -> T {
        return values[index.base].0
    }
    
}

// MARK: - ExtensibleCollectionType

extension Set: ExtensibleCollectionType {
    
    /// In theory, reserve capacity for `n` elements. However, Dictionary does not implement reserveCapacity(), so we just silently ignore it.
    public func reserveCapacity(n: Int) {}
    
    public mutating func extend<S: SequenceType where S.Generator.Element == T>(sequence: S) {
        // Note that this should just be for each in sequence; this is working around a compiler crasher.
        for each in SequenceOf<T>(sequence) {
            insert(each)
        }
    }
    
    public mutating func append(element: T) {
        insert(element)
    }
    
}

// MARK: - Hashable

public func ==<T>(a: Set<T>, b: Set<T>) -> Bool {
    return a.values == b.values
}

extension Set: Equatable { }

// MARK: ArrayLiteralConvertible

extension Set: ArrayLiteralConvertible {
    
    public init(arrayLiteral elements: T...) {
        self.init(elements)
    }
    
}

// MARK: UnorderedCollectionType

extension Set: UnorderedCollectionType {
    
    public func contains(element: T) -> Bool {
        return values[element] != nil
    }
    
    public mutating func insert(element: T) -> Bool {
        return values.updateValue(.Some, forKey: element) == nil
    }
    
    public mutating func remove(element: T) -> Bool {
        return values.removeValueForKey(element) != nil
    }
    
    public mutating func intersect<S: UnorderedCollectionType where S.Generator.Element == T>(set: S) {
        for element in self {
            if !set.contains(element) {
                remove(element)
            }
        }
    }

    public mutating func difference<Seq: SequenceType where Seq.Generator.Element == T>(sequence: Seq) {
        for element in SequenceOf<T>(sequence) {
            remove(element)
        }
    }
    
}

// MARK: - Printable

extension Set: Printable, DebugPrintable {
    
    public var description: String {
        let list = join(", ", map(toString))
        return "{\(list)}"
    }
    
    public var debugDescription: String {
        return description
    }
    
}

// MARK: Convenience

extension Set {
    
    /// Removes all elements from the receiver.
    public mutating func removeAll(keepCapacity: Bool = false) {
        values.removeAll(keepCapacity: keepCapacity)
    }
    
    /// Returns a new set including only those elements `x` where `includeElement(x)` is true.
    public func filter(includeElement: T -> Bool) -> Set<T> {
        return Set(Swift.filter(self, includeElement))
    }
    
    /// Returns a new set with the result of applying `transform` to each element.
    public func map<Result>(transform: T -> Result) -> Set<Result> {
        return flatMap { [transform($0)] }
    }
    
    /// Applies `transform` to each element and returns a new set which is the union of each resulting set.
    public func flatMap<R, S: SequenceType where S.Generator.Element == R>(transform: T -> S) -> Set<R> {
        return reduce(Set<R>()) { $0 + transform($1) }
    }
    
    /// Combines each element of the receiver with an accumulator value using `combine`, starting with `initial`.
    public func reduce<U>(initial: U, combine: (U, T) -> U) -> U {
        return Swift.reduce(self, initial, combine)
    }
    
}

// MARK: SetIndex

public struct SetIndex<T : Hashable>: BidirectionalIndexType, Comparable {
    
    private typealias Base = DictionaryIndex<T, Unit>
    private let base: Base
    
    private init(_ base: Base) {
        self.base = base
    }
    
    public func predecessor() -> SetIndex<T> {
        return SetIndex(base.predecessor())
    }
    
    public func successor() -> SetIndex<T> {
        return SetIndex(base.successor())
    }
    
}

public func ==<T>(lhs: SetIndex<T>, rhs: SetIndex<T>) -> Bool {
    return lhs.base == rhs.base
}

public func <<T>(lhs: SetIndex<T>, rhs: SetIndex<T>) -> Bool {
    return lhs.base < rhs.base
}

// MARK: Unit

/// A singleton type.
private enum Unit {
    case Some
}

