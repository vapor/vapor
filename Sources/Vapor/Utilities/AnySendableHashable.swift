/// A `Sendable` version of the standard library's `AnyHashable` type.
public struct AnySendableHashable: @unchecked Sendable, Hashable, ExpressibleByStringLiteral {
    // Note: @unchecked Sendable since there's no way to express that `wrappedValue` is Sendable, even though we ensure that it is in the init.
    @usableFromInline
    let wrappedValue: AnyHashable

    @inlinable
    public init(_ wrappedValue: some Hashable & Sendable) {
        self.wrappedValue = AnyHashable(wrappedValue)
    }

    @inlinable
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension AnySendableHashable: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    @inlinable public var description: String { self.wrappedValue.description }
    @inlinable public var debugDescription: String { self.wrappedValue.debugDescription }
    @inlinable public var customMirror: Mirror { self.wrappedValue.customMirror }
}

extension Dictionary where Key == AnySendableHashable {
    public subscript(key: some Hashable & Sendable) -> Value? {
        @inlinable get { self[AnySendableHashable(key)] }
        @inlinable set { self[AnySendableHashable(key)] = newValue }
    }
}
