/// Types conforming to ``Extendable`` can have stored properties added in extension by using the ``Extend`` struct.
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
    /// Arbitrary property storage. See ``Extend`` and ``Extendable``.
    var extend: Extend { get set }
}

/// A wrapper around a simple `[String: Any]` storage dictionary used to implement ``Extendable``.
///
///     final cass MyType: Extendable { ... }
///     extension MyType {
///         var foo: Int {
///             get { return extend.get(\MyType.foo, default: 0) }
///             set { extend.set(\MyType.foo, to: newValue) }
///         }
///     }
///
/// > Note: ``Extend`` conforms to Codable, but will yield an empty dictionary.
/// > Extensions are used for convenience and should not be encoded or decoded.
public struct Extend: Codable, ExpressibleByDictionaryLiteral {
    /// The internal storage.
    public var storage: [String: Any]

    /// Create a new extend.
    public init() {
        self.storage = [:]
    }

    // See `Encodable.encode(to:)`.
    public func encode(to encoder: any Encoder) throws {
        // skip
    }

    // See `Deodable.init(from:)`.
    public init(from decoder: any Decoder) throws {
        // skip
        self.storage = [:]
    }

    // See `ExpressibleByDictionaryLiteral.init(dictionaryLiteral:)`.
    public init(dictionaryLiteral elements: (String, Any)...) {
        self.init()
        for (key, value) in elements {
            self[key] = value
        }
    }

    /// Gets a value from the ``Extend`` storage falling back to the default value if it does not exist
    /// or cannot be cast to `T`.
    ///
    /// `KeyPath`-based alternative to ``get(_:default:)-7134n``.
    ///
    ///     let foo: Foo = extend.get(\MyType.Foo, default: defaultFoo)
    ///
    public func get<T>(_ key: AnyKeyPath, `default` d: T) -> T {
        get(key.hashValue.description, default: d)
    }

    /// Set a value to the ``Extend`` storage.
    ///
    /// `KeyPath`-based alternative to ``set(_:to:)-3vesn``.
    ///
    ///     extend.set(\MyType.Foo, to: foo)
    ///
    public mutating func set<T>(_ key: AnyKeyPath, to newValue: T) {
        set(key.hashValue.description, to: newValue)
    }

    /// Gets a value from the ``Extend`` storage falling back to the default value if it does not exist
    /// or cannot be cast to `T`.
    ///
    ///     let foo: Foo = extend.get("foo", default: defaultFoo)
    ///
    public func get<T>(_ key: String, `default` d: T) -> T {
        self[key] as? T ?? d
    }

    /// Set a value to the ``Extend`` storage.
    ///
    ///     extend.set("foo", to: foo)
    ///
    public mutating func set<T>(_ key: String, to newValue: T) {
        self[key] = newValue
    }

    /// Allow subscripting by `String` key. This is a type-erased alternative to
    /// the ``get(_:default:)-7134n`` and ``set(_:to:)-3vesn`` methods.
    ///
    ///     extend["foo"]
    ///
    public subscript(_ key: String) -> Any? {
        get { self.storage[key] }
        set { self.storage[key] = newValue }
    }
}
