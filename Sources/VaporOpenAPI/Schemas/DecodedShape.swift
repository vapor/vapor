#if OpenAPI

/// What a type's `init(from:)` asked a ``SchemaDecoder`` for, as a tree of nodes.
struct DecodedShape: Sendable {
    /// The type this node was decoded as.
    var type: Any.Type
    var kind: Kind
    /// Whether the type checked for `null`, as `Optional` does.
    var isNullable = false

    indirect enum Kind {
        /// A type with a builtin or provided schema, decoded from a placeholder.
        case leaf
        /// An object with fixed properties, in the order they were decoded.
        case keyed([Field])
        /// An object with any keys, all holding values of the same shape.
        case dictionary(DecodedShape)
        /// An array; `nil` if no element was decoded.
        case unkeyed(DecodedShape?)
        /// A wrapper around a single value, such as `Optional` or a raw-value enum.
        case single(DecodedShape)
        /// The type is already being decoded further up, so it refers to itself.
        case recursive
        /// The type asked for no container at all.
        case empty
    }

    struct Field {
        var name: String
        var shape: DecodedShape
        /// Decoded with `decodeIfPresent`, so it may be missing.
        var isOptional: Bool
    }
}

#endif
