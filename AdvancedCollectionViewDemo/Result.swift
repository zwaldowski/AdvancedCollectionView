/// Result
///
/// Container for a successful value (T) or a failure with an NSError
///

import Foundation

/// A success `Result` returning `value`
/// This form is preferred to `Result.Success(Box(value))` because it
// does not require dealing with `Box()`
public func success<T>(value: T) -> Result<T> {
    return .Success(Box(value))
}

/// A failure `Result` returning `error`
/// The default error is an empty one so that `failure()` is legal
/// To assign this to a variable, you must explicitly give a type.
/// Otherwise the compiler has no idea what `T` is. This form is preferred
/// to Result.Failure(error) because it provides a useful default.
/// For example:
///    let fail: Result<Int> = failure()
///

/// Dictionary keys for default errors
public let ErrorFileKey = "LMErrorFile"
public let ErrorLineKey = "LMErrorLine"

private func defaultError(userInfo: [NSObject: AnyObject]) -> NSError {
    return NSError(domain: "", code: 0, userInfo: userInfo)
}

private func defaultError(message: String, file: String = __FILE__, line: Int = __LINE__) -> NSError {
    return defaultError([NSLocalizedDescriptionKey: message])
}

public func failure<T>(message: String) -> Result<T> {
    let userInfo: [NSObject : AnyObject] = [NSLocalizedDescriptionKey: message]
    return failure(defaultError(userInfo))
}

public func failure<T>() -> Result<T> {
    let userInfo: [NSObject : AnyObject] = [:]
    return failure(defaultError(userInfo))
}

public func failure<T>(error: NSError) -> Result<T> {
    return .Failure(error)
}

/// Container for a successful value (T) or a failure with an E
public enum Result<T> {
    case Success(Box<T>)
    case Failure(NSError)

    /// The successful value as an Optional
    public var value: T? {
        switch self {
            case .Success(let box): return box.unbox
            case .Failure: return nil
        }
    }

    /// The failing error as an Optional
    public var error: NSError? {
        switch self {
            case .Success: return nil
            case .Failure(let err): return err
        }
    }

    public var isSuccess: Bool {
        switch self {
            case .Success: return true
            case .Failure: return false
        }
    }

    /// Return a new result after applying a transformation to a successful value.
    /// Mapping a failure returns a new failure without evaluating the transform
    public func map<U>(transform: T -> U) -> Result<U> {
        switch self {
            case Success(let box):
            return .Success(Box(transform(box.unbox)))
            case Failure(let err):
            return .Failure(err)
        }
    }

    /// Return a new result after applying a transformation (that itself
    /// returns a result) to a successful value.
    /// Calling with a failure returns a new failure without evaluating the transform
    public func flatMap<U>(transform:T -> Result<U>) -> Result<U> {
        switch self {
            case Success(let value): return transform(value.unbox)
            case Failure(let error): return .Failure(error)
        }
    }
}

extension Result: Printable {
    public var description: String {
        switch self {
            case .Success(let box):
            return "Success: \(box.unbox)"
            case .Failure(let error):
            return "Failure: \(error)"
        }
    }
}

/// Failure coalescing
///    .Success(Box(42)) ?? 0 ==> 42
///    .Failure(NSError()) ?? 0 ==> 0
public func ??<T,E>(result: Result<T>, defaultValue: @autoclosure () -> T) -> T {
    switch result {
        case .Success(let value):
        return value.unbox
        case .Failure(let error):
        return defaultValue()
    }
}

/// Due to current swift limitations, we have to include this Box in Result.
/// Swift cannot handle an enum with multiple associated data (A, NSError) where one is of unknown size (A)
final public class Box<T> {
    public let unbox: T
    public init(_ value: T) { self.unbox = value }
}
