/// Types conforming to `Extendable` can have stored properties added in extension by using the `Extend` struct.
///
///     final cass MyType: Extendable { ... }
///     extension MyType {
///         var foo: Int {
///             get { return extend.get(\MyType.foo, default: 0) }
///             set { extend.set(\MyType.foo, to: newValue) }
///         }
///     }
///
public protocol Extendable: AnyObject {
    /// Arbitrary property storage. See `Extend` and `Extendable`.
    var extend: Extend { get set }
}

/// A wrapper around a simple [String: Any] storage dictionary used to implement `Extendable`.
///
///     final cass MyType: Extendable { ... }
///     extension MyType {
///         var foo: Int {
///             get { return extend.get(\MyType.foo, default: 0) }
///             set { extend.set(\MyType.foo, to: newValue) }
///         }
///     }
///
/// - note: `Extend` conforms to Codable, but will yield an empty dictionary.
///         Extensions are used for convenience and should not be encoded or decoded.
public struct Extend: Codable, ExpressibleByDictionaryLiteral {
    /// The internal storage.
    public var storage: [String: Any]

    /// Create a new extend.
    public init() {
        storage = [:]
    }

    /// See `Codable`.
    public func encode(to encoder: any Encoder) throws {
        // skip
    }

    /// See `Codable`.
    public init(from decoder: any Decoder) throws {
        // skip
        storage = [:]
    }

    /// See `ExpressibleByDictionaryLiteral`.
    public init(dictionaryLiteral elements: (String, Any)...) {
        self.init()
        for (key, value) in elements {
            self[key] = value
        }
    }

    /// Gets a value from the `Extend` storage falling back to the default value if it does not exist
    /// or cannot be casted to `T`.
    ///
    /// `KeyPath`-based alternative to `get(_:default:)`.
    ///
    ///     let foo: Foo = extend.get(\MyType.Foo, default: defaultFoo)
    ///
    public func get<T>(_ key: AnyKeyPath, `default` d: T) -> T {
        return get(key.hashValue.description, default: d)
    }

    /// Set a value to the `Extend` storage.
    ///
    /// `KeyPath`-based alternative to `set(_:to:)`.
    ///
    ///     extend.set(\MyType.Foo, to: foo)
    ///
    public mutating func set<T>(_ key: AnyKeyPath, to newValue: T) {
        set(key.hashValue.description, to: newValue)
    }

    /// Gets a value from the `Extend` storage falling back to the default value if it does not exist
    /// or cannot be casted to `T`.
    ///
    ///     let foo: Foo = extend.get("foo", default: defaultFoo)
    ///
    public func get<T>(_ key: String, `default` d: T) -> T {
        return self[key] as? T ?? d
    }

    /// Set a value to the `Extend` storage.
    ///
    ///     extend.set("foo", to: foo)
    ///
    public mutating func set<T>(_ key: String, to newValue: T) {
        return self[key] = newValue
    }

    /// Allow subscripting by `String` key. This is a type-erased alternative to
    /// the `get(_:default:)` and `set(:to:)` methods.
    ///
    ///     extend["foo"]
    ///
    public subscript(_ key: String) -> Any? {
        get { return storage[key] }
        set { storage[key] = newValue }
    }
}
