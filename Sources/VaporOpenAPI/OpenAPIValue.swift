#if OpenAPI
/// What a request or response body contains, described by a type, an example, or a combination
/// of other bodies.
///
/// The schema itself is generated later, when the document is built.
public struct OpenAPIBody: Sendable {
    let value: OpenAPIValue

    /// A body whose schema is derived from `type`.
    ///
    /// The type is inspected through `Decodable`, so this sees every property, including optional
    /// ones. A type that's only `Encodable` can describe itself with ``OpenAPISchemaProvider``.
    public static func type<T: Decodable & SendableMetatype>(_ type: T.Type) -> Self {
        OpenAPIBody(value: .type(type))
    }

    /// A body described by the type of `value`, as with ``type(_:)``, with `value` as its example.
    ///
    /// The schema still comes from the type, so a `nil` property is described too. The type must
    /// be `Decodable`, or describe itself with ``OpenAPISchemaProvider``.
    public static func example(_ value: some Encodable & Sendable) -> Self {
        OpenAPIBody(value: .example(value))
    }

    /// A body that matches every one of the given bodies (`allOf`).
    public static func all(of first: OpenAPIBody, _ rest: OpenAPIBody...) -> Self {
        all(of: [first] + rest)
    }

    /// A body that matches every one of `bodies` (`allOf`).
    ///
    /// - Precondition: `bodies` isn't empty.
    public static func all(of bodies: [OpenAPIBody]) -> Self {
        precondition(!bodies.isEmpty, "OpenAPIBody.all(of:) needs at least one body")
        return OpenAPIBody(value: .allOf(bodies.map(\.value)))
    }

    /// A body that matches at least one of the given bodies (`anyOf`).
    public static func any(of first: OpenAPIBody, _ rest: OpenAPIBody...) -> Self {
        any(of: [first] + rest)
    }

    /// A body that matches at least one of `bodies` (`anyOf`).
    ///
    /// - Precondition: `bodies` isn't empty.
    public static func any(of bodies: [OpenAPIBody]) -> Self {
        precondition(!bodies.isEmpty, "OpenAPIBody.any(of:) needs at least one body")
        return OpenAPIBody(value: .anyOf(bodies.map(\.value)))
    }

    /// A body that matches exactly one of the given bodies (`oneOf`).
    public static func one(of first: OpenAPIBody, _ rest: OpenAPIBody...) -> Self {
        one(of: [first] + rest)
    }

    /// A body that matches exactly one of `bodies` (`oneOf`).
    ///
    /// - Precondition: `bodies` isn't empty.
    public static func one(of bodies: [OpenAPIBody]) -> Self {
        precondition(!bodies.isEmpty, "OpenAPIBody.one(of:) needs at least one body")
        return OpenAPIBody(value: .oneOf(bodies.map(\.value)))
    }

    /// A body that doesn't match `body` (`not`).
    public static func not(_ body: OpenAPIBody) -> Self {
        OpenAPIBody(value: .not(body.value))
    }
}

/// The parameters an operation takes, described by a type or an example whose properties
/// become the parameters.
///
/// Where they're sent, such as the query or headers, is chosen when they're attached to a route.
public struct OpenAPIParameters: Sendable {
    let value: OpenAPIValue

    /// Parameters taken from the properties of `type`.
    ///
    /// The type is inspected through `Decodable`, so this sees every property, including optional
    /// ones. A type that's only `Encodable` can describe itself with ``OpenAPISchemaProvider``.
    public static func type<T: Decodable & SendableMetatype>(_ type: T.Type) -> Self {
        OpenAPIParameters(value: .type(type))
    }

    /// Parameters taken from the properties of `value`'s type, with `value` providing their examples.
    ///
    /// The parameters still come from the type, so a `nil` property is a parameter with no example.
    /// The type must be `Decodable`, or describe itself with ``OpenAPISchemaProvider``.
    public static func example(_ value: some Encodable & Sendable) -> Self {
        OpenAPIParameters(value: .example(value))
    }

    /// The parameters of every one of `parameters`, combined into one list.
    public static func all(of parameters: OpenAPIParameters...) -> Self {
        all(of: parameters)
    }

    /// The parameters of every one of `parameters`, combined into one list.
    ///
    /// Nested combinations are flattened, since parameters are always a single list.
    public static func all(of parameters: [OpenAPIParameters]) -> Self {
        let values = parameters.flatMap { parameter -> [OpenAPIValue] in
            if case .allOf(let nested) = parameter.value { nested } else { [parameter.value] }
        }
        return OpenAPIParameters(value: .allOf(values))
    }
}

extension OpenAPIParameters: ExpressibleByArrayLiteral {
    /// Combines the listed parameters, as with `all(of:)`.
    public init(arrayLiteral elements: OpenAPIParameters...) {
        self = .all(of: elements)
    }
}

/// How a body or set of parameters is described, before it's turned into a schema.
enum OpenAPIValue: Sendable {
    case type(any (Decodable & SendableMetatype).Type)
    case example(any Encodable & Sendable)
    case allOf([OpenAPIValue])
    case anyOf([OpenAPIValue])
    case oneOf([OpenAPIValue])
    indirect case not(OpenAPIValue)
}
#endif
