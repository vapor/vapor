import NIOCore

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
