//  Copyright (c) 2014 Rob Rix. All rights reserved.

/// A set of unique elements as determined by `hashValue` and `==`.
public struct Set<Element: Hashable> {
    
    /// The underlying dictionary.
    private var values: [Element: Unit]
    
    /// Constructs a `Set` with a dictionary of `values`.
    private init(values: [Element: Unit]) {
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
        self.init(values: [Element:Unit](minimumCapacity: minimumCapacity))
    }
    
    public init<S: SequenceType where S.Generator.Element == Element>(_ sequence: S) {
        self.init()
        extend(sequence)
    }
    
    public init(element: Element) {
        self.init(values: [ element: Unit() ])
    }
    
}

// MARK: SequenceType

extension Set: SequenceType {
    
    public func generate() -> GeneratorOf<Element> {
        return GeneratorOf(values.keys.generate())
    }
    
}

// MARK: - CollectionType

extension Set: CollectionType {
    
    typealias Index = DictionaryIndex<Element, Unit>
    
    public var startIndex: Index { return values.startIndex }
    public var endIndex: Index { return values.endIndex }
    
    public subscript(v: ()) -> Element {
        get { return values[values.startIndex].0 }
        set { insert(newValue) }
    }
    
    public subscript(index: Index) -> Element {
        return values[index].0
    }
    
}

// MARK: - ExtensibleCollectionType

extension Set: ExtensibleCollectionType {
    
    /// In theory, reserve capacity for `n` elements. However, Dictionary does not implement reserveCapacity(), so we just silently ignore it.
    public func reserveCapacity(n: Set<Element>.Index.Distance) {}
    
    public mutating func extend<S: SequenceType where S.Generator.Element == Element>(sequence: S) {
        // Note that this should just be for each in sequence; this is working around a compiler crasher.
        for each in SequenceOf<Element>(sequence) {
            insert(each)
        }
    }
    
    public mutating func append(element: Element) {
        insert(element)
    }
    
}

// MARK: - Hashable

public func ==<Element: Hashable>(a: Set<Element>, b: Set<Element>) -> Bool {
    return a.values == b.values
}

extension Set: Equatable { }

// MARK: ArrayLiteralConvertible

extension Set: ArrayLiteralConvertible {
    
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
    
}

// MARK: SetType

extension Set: SetType {
    
    public func contains(element: Element) -> Bool {
        return values[element] != nil
    }
    
    public mutating func insert(element: Element) -> Bool {
        return values.updateValue(Unit(), forKey: element) == nil
    }
    
    public mutating func remove(element: Element) -> Bool {
        return values.removeValueForKey(element) != nil
    }
    
    public mutating func intersect<S: SetType where S.Generator.Element == Element>(set: S) {
        for element in self {
            if !set.contains(element) {
                remove(element)
            }
        }
    }

    public mutating func difference<Seq: SequenceType where Seq.Generator.Element == Element>(sequence: Seq) {
        for element in SequenceOf<Element>(sequence) {
            remove(element)
        }
    }
    
}

// MARK: - Printable

extension Set: Printable {
    
    public var description: String {
        let list = join(", ", map(toString))
        return "{\(list)}"
    }
    
}

// MARK: Convenience

extension Set {
    
    /// Removes all elements from the receiver.
    public mutating func removeAll(keepCapacity: Bool = false) {
        values.removeAll(keepCapacity: keepCapacity)
    }
    
    /// Returns a new set with the result of applying `transform` to each element.
    public func map<Result>(transform: Element -> Result) -> Set<Result> {
        return flatMap { [transform($0)] }
    }
    
    /// Applies `transform` to each element and returns a new set which is the union of each resulting set.
    public func flatMap<Result, S: SequenceType where S.Generator.Element == Result>(transform: Element -> S) -> Set<Result> {
        return reduce(Set<Result>()) { $0 + transform($1) }
    }
    
    /// Combines each element of the receiver with an accumulator value using `combine`, starting with `initial`.
    public func reduce<Into>(initial: Into, combine: (Into, Element) -> Into) -> Into {
        return Swift.reduce(self, initial, combine)
    }
    
}
