import NIOCore

extension EventLoopFuture where Value: OptionalType & VaporSendableMetatype {
    /// Unwraps an `Optional` value contained inside a Future's expectation.
    /// If the optional resolves to `nil` (`.none`), the supplied error will be thrown instead.
    ///
    ///     print(futureString) // Future<String?>
    ///     futureString.unwrap(or: MyError()) // Future<String>
    ///
    /// - parameters:
    ///     - error: `Error` to throw if the value is `nil`. This is captured with `@autoclosure`
    ///              to avoid initialize the `Error` unless needed.
    public func unwrap(or error: @Sendable @autoclosure @escaping () -> Error) -> EventLoopFuture<Value.WrappedType> {
        return self.flatMapThrowing { optional -> Value.WrappedType in
            guard let wrapped = optional.wrapped else {
                throw error()
            }
            return wrapped
        }
    }
}

/// Applies `nil` coalescing to a future's optional and a concrete type.
///
///     print(maybeFutureInt) // Future<Int>?
///     let futureInt = maybeFutureInt ?? 0
///     print(futureInt) // Future<Int>
///
public func ??<T: Sendable>(lhs: EventLoopFuture<T?>, rhs: T) -> EventLoopFuture<T> {
    return lhs.map { value in
        return value ?? rhs
    }
}

/// Capable of being represented by an optional wrapped type.
///
/// This protocol mostly exists to allow constrained extensions on generic
/// types where an associatedtype is an `Optional<T>`.
public protocol OptionalType: AnyOptionalType {
    /// Underlying wrapped type.
    associatedtype WrappedType
    
    /// Returns the wrapped type, if it exists.
    var wrapped: WrappedType? { get }
    
    /// Creates this optional type from an optional wrapped type.
    static func makeOptionalType(_ wrapped: WrappedType?) -> Self
}

/// Conform concrete optional to `OptionalType`.
/// See `OptionalType` for more information.
extension Optional: OptionalType {
    /// See `OptionalType.WrappedType`
    public typealias WrappedType = Wrapped
    
    /// See `OptionalType.wrapped`
    public var wrapped: Wrapped? {
        switch self {
        case .none: return nil
        case .some(let w): return w
        }
    }
    
    /// See `OptionalType.makeOptionalType`
    public static func makeOptionalType(_ wrapped: Wrapped?) -> Optional<Wrapped> {
        return wrapped
    }
}

/// Type-erased `OptionalType`
public protocol AnyOptionalType {
    /// Returns the wrapped type, if it exists.
    var anyWrapped: Any? { get }
    
    /// Returns the wrapped type, if it exists.
    static var anyWrappedType: Any.Type { get }
}

extension AnyOptionalType where Self: OptionalType {
    /// See `AnyOptionalType.anyWrapped`
    public var anyWrapped: Any? { return wrapped }
    
    /// See `AnyOptionalType.anyWrappedType`
    public static var anyWrappedType: Any.Type { return WrappedType.self }
}
