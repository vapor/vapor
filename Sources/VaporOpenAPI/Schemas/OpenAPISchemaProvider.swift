#if OpenAPI
import OpenAPIKit

/// A type that describes its own JSON schema, instead of having it derived from how it decodes.
///
/// Conform types whose encoding the generator can't see, or whose schema should say more than
/// their structure does. A conformance takes precedence over the builtin schema for standard
/// library and Foundation types, so it can also describe a different encoding of one of them:
///
/// ```swift
/// // The app encodes dates as seconds since 1970.
/// extension Date: @retroactive OpenAPISchemaProvider {
///     static var openAPISchema: OpenAPISchema { .number(format: .double) }
/// }
/// ```
public protocol OpenAPISchemaProvider: Sendable {
    /// The schema that describes every value of this type.
    static var openAPISchema: OpenAPISchema { get }

    /// Any value of this type, used in place of decoding one when this type is a property of
    /// another type whose schema is derived from how it decodes.
    ///
    /// Provide one when `init(from:)` can't decode placeholder values, as for an enum with
    /// associated values:
    ///
    /// ```swift
    /// static var openAPIPlaceholder: Shape? { .circle(radius: 0) }
    /// ```
    ///
    /// The default is `nil`, which decodes the type as usual. Declare it as optional, `Self?`:
    /// a non-optional `openAPIPlaceholder` doesn't satisfy this requirement, so it's ignored.
    static var openAPIPlaceholder: Self? { get }
}

extension OpenAPISchemaProvider {
    public static var openAPIPlaceholder: Self? { nil }
}

extension OpenAPISchemaProvider where Self: CaseIterable & RawRepresentable, RawValue == String {
    /// A string limited to the raw values of the cases, in declaration order.
    ///
    /// A string-backed enum only needs to conform: `enum Role: String, CaseIterable, OpenAPISchemaProvider`.
    /// It traps for an enum with no cases, since OpenAPI has no schema that matches no values.
    public static var openAPISchema: OpenAPISchema {
        precondition(!allCases.isEmpty, "\(Self.self) has no cases, so it can't be described as an enum")
        return OpenAPISchema.enumeration(allCases.map(\.rawValue))
    }
}

extension JSONSchema {
    /// The schema `type` describes itself with, or else its builtin schema, or `nil` if it has neither.
    ///
    /// Containers such as `Optional` and `Array` aren't resolved here, even when their elements
    /// have a schema: they're described from how they decode.
    static func schema(for type: Any.Type) -> JSONSchema? {
        if let provider = type as? any OpenAPISchemaProvider.Type {
            return provider.openAPISchema.schema
        }
        return .builtin(for: type)
    }
}

#endif
