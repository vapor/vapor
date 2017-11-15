/// Represents an encodable value that should
/// be bound to the database drivers. There
/// will be a related placeholder that appears
/// in the serialized query.
public struct BindValue {
    /// The underlying encodable data.
    public var encodable: Encodable

    /// The method to encode this data.
    /// note: this is usually .plain
    public var method: BindValueMethod
}

/// Various bind value methods.
/// Some binds should have special
/// characters affixed to them for
/// things like comparing suffix/prefix.
public enum BindValueMethod {
    case plain
    case wildcard(BindWildcard)
}

/// Prepend, append, or fully enclose
/// the bind in a wildcard.
public enum BindWildcard {
    case leadingWildcard // %s
    case trailingWildcard // s%
    case fullWildcard // %s%
}
