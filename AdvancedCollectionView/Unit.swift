//  Copyright (c) 2014 Rob Rix. All rights reserved.

/// A singleton type.
public struct Unit {}


/// Unit is Equatable.
extension Unit: Equatable {}

public func == (a: Unit, b: Unit) -> Bool { return true }
