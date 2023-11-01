import Foundation

/// A `Sendable` version of the standard library's `AnyHashable` type.
public struct AnySendableHashable: @unchecked Sendable, Hashable, ExpressibleByStringLiteral {
    // Note: @unchecked Sendable since there's no way to express that `wrappedValue` is Sendable, even though we ensure that it is in the init.
    let wrappedValue: AnyHashable
    
    public init(_ wrappedValue: any Hashable & Sendable) {
        self.wrappedValue = AnyHashable(wrappedValue)
    }
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
