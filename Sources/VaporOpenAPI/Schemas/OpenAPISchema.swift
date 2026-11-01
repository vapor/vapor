#if OpenAPI
import OpenAPIKit

/// A JSON schema written by hand, for when the one derived from a type isn't what you want.
///
/// We wrap OpenAPIKit's schema rather than expose it, so OpenAPIKit's major versions don't leak
/// into Vapor's API. Build one from the static factories and refine it with the modifiers:
///
/// ```swift
/// .object([
///     "id": .string(format: .uuid),
///     "nickname": .string().optional(),
///     "tags": .array(of: .string()),
/// ])
/// ```
public struct OpenAPISchema: Sendable, Equatable {
    let schema: JSONSchema

    /// A string, optionally in a well-known `format` such as ``StringFormat/uuid``.
    public static func string(format: StringFormat? = nil) -> Self {
        Self(schema: .string(format: format?.jsonFormat ?? .unspecified))
    }

    /// A whole number, optionally in a fixed-size `format` such as ``IntegerFormat/int64``.
    public static func integer(format: IntegerFormat? = nil) -> Self {
        Self(schema: .integer(format: format?.jsonFormat ?? .unspecified))
    }

    /// A number with a fractional part, optionally in a `format` such as ``NumberFormat/double``.
    public static func number(format: NumberFormat? = nil) -> Self {
        Self(schema: .number(format: format?.jsonFormat ?? .unspecified))
    }

    /// `true` or `false`.
    public static var boolean: Self {
        Self(schema: .boolean)
    }

    /// A list whose elements all match `items`.
    public static func array(of items: OpenAPISchema) -> Self {
        Self(schema: .array(items: items.schema))
    }

    /// An object with the given properties, in the order they're listed.
    ///
    /// Every property is required unless it's marked with ``optional()``. A Swift `T?` property
    /// is usually left out when it's `nil`, so mark it `optional()` rather than `nullable()`.
    public static func object(_ properties: KeyValuePairs<String, OpenAPISchema> = [:]) -> Self {
        let properties = OrderedDictionary(
            properties.map { ($0.key, $0.value.schema) },
            uniquingKeysWith: { _, last in last }
        )
        return Self(schema: .object(properties: properties))
    }

    /// An object with arbitrary keys whose values all match `values`, like `[String: Value]`.
    public static func dictionary(of values: OpenAPISchema) -> Self {
        Self(schema: .object(additionalProperties: .b(values.schema)))
    }

    /// A string that must be one of `values`, like a `String`-backed enum.
    ///
    /// A single value is written as `const`, which means the same thing.
    ///
    /// - Precondition: `values` isn't empty, since an empty enum matches nothing.
    public static func enumeration(_ values: [String]) -> Self {
        precondition(!values.isEmpty, "OpenAPISchema.enumeration(_:) needs at least one value")
        return Self(schema: .string(allowedValues: values.map { AnyCodable($0) }))
    }

    /// A value that matches exactly one of the given schemas (`oneOf`).
    ///
    /// Use it for an enum with associated values, which `Codable` writes as an object keyed by
    /// the case:
    ///
    /// ```swift
    /// .one(of:
    ///     .object(["circle": .object(["radius": .number()])]),
    ///     .object(["square": .object(["side": .number()])])
    /// )
    /// ```
    public static func one(of first: OpenAPISchema, _ rest: OpenAPISchema...) -> Self {
        one(of: [first] + rest)
    }

    /// A value that matches exactly one of `schemas` (`oneOf`).
    ///
    /// - Precondition: `schemas` isn't empty.
    public static func one(of schemas: [OpenAPISchema]) -> Self {
        precondition(!schemas.isEmpty, "OpenAPISchema.one(of:) needs at least one schema")
        return Self(schema: .one(of: schemas.map(\.schema)))
    }

    /// A value that matches at least one of the given schemas (`anyOf`).
    public static func any(of first: OpenAPISchema, _ rest: OpenAPISchema...) -> Self {
        any(of: [first] + rest)
    }

    /// A value that matches at least one of `schemas` (`anyOf`).
    ///
    /// - Precondition: `schemas` isn't empty.
    public static func any(of schemas: [OpenAPISchema]) -> Self {
        precondition(!schemas.isEmpty, "OpenAPISchema.any(of:) needs at least one schema")
        return Self(schema: .any(of: schemas.map(\.schema)))
    }

    /// A value that matches every one of the given schemas (`allOf`).
    public static func all(of first: OpenAPISchema, _ rest: OpenAPISchema...) -> Self {
        all(of: [first] + rest)
    }

    /// A value that matches every one of `schemas` (`allOf`).
    ///
    /// - Precondition: `schemas` isn't empty.
    public static func all(of schemas: [OpenAPISchema]) -> Self {
        precondition(!schemas.isEmpty, "OpenAPISchema.all(of:) needs at least one schema")
        return Self(schema: .all(of: schemas.map(\.schema)))
    }

    /// The same schema, as a property that may be left out of its object.
    ///
    /// This only has an effect on an object's property: for `[T?]`, use ``nullable()`` instead.
    public func optional() -> Self {
        Self(schema: schema.optionalSchemaObject())
    }

    /// The same schema, also allowing `null`.
    ///
    /// For an ``enumeration(_:)``, `null` is added to the allowed values too, since a value has
    /// to match both the type and the enum.
    public func nullable() -> Self {
        Self(schema: schema.allowingNull())
    }

    /// The same schema, with a description shown in the generated document.
    public func description(_ description: String) -> Self {
        Self(schema: schema.with(description: description))
    }
}

extension OpenAPISchema {
    /// A well-known format for a string, such as a date or a UUID.
    ///
    /// A struct rather than an enum, so formats can be added without breaking exhaustive
    /// switches downstream. Use ``other(_:)`` for a format that isn't listed here.
    public struct StringFormat: Sendable, Equatable {
        let jsonFormat: JSONTypeFormat.StringFormat

        /// A full date, such as `2026-10-25`.
        public static let date = Self(jsonFormat: .date)
        /// A date and time, such as `2026-10-25T08:45:00Z`.
        public static let dateTime = Self(jsonFormat: .dateTime)
        /// A time of day, such as `08:45:00Z`.
        public static let time = Self(jsonFormat: .time)
        /// A duration, such as `P3D`.
        public static let duration = Self(jsonFormat: .duration)
        public static let email = Self(jsonFormat: .email)
        public static let idnEmail = Self(jsonFormat: .idnEmail)
        public static let hostname = Self(jsonFormat: .hostname)
        public static let idnHostname = Self(jsonFormat: .idnHostname)
        public static let ipv4 = Self(jsonFormat: .ipv4)
        public static let ipv6 = Self(jsonFormat: .ipv6)
        public static let uri = Self(jsonFormat: .uri)
        public static let uriReference = Self(jsonFormat: .uriReference)
        public static let uriTemplate = Self(jsonFormat: .uriTemplate)
        public static let iri = Self(jsonFormat: .iri)
        public static let iriReference = Self(jsonFormat: .iriReference)
        public static let uuid = Self(jsonFormat: .uuid)
        public static let jsonPointer = Self(jsonFormat: .jsonPointer)
        public static let relativeJsonPointer = Self(jsonFormat: .relativeJsonPointer)
        public static let regex = Self(jsonFormat: .regex)
        /// A hint that the value should be hidden in UIs.
        public static let password = Self(jsonFormat: .password)

        /// A format that isn't listed here, such as `phone`.
        ///
        /// An empty name means no format, and a listed name such as `"uuid"` is the same as that format.
        public static func other(_ format: String) -> Self {
            Self(jsonFormat: .other(format))
        }
    }

    /// A fixed size for an integer.
    public struct IntegerFormat: Sendable, Equatable {
        let jsonFormat: JSONTypeFormat.IntegerFormat

        public static let int32 = Self(jsonFormat: .int32)
        public static let int64 = Self(jsonFormat: .int64)

        /// A format that isn't listed here.
        ///
        /// An empty name means no format, and a listed name such as `"uuid"` is the same as that format.
        public static func other(_ format: String) -> Self {
            Self(jsonFormat: .other(format))
        }
    }

    /// A precision for a number.
    public struct NumberFormat: Sendable, Equatable {
        let jsonFormat: JSONTypeFormat.NumberFormat

        public static let float = Self(jsonFormat: .float)
        public static let double = Self(jsonFormat: .double)

        /// A format that isn't listed here.
        ///
        /// An empty name means no format, and a listed name such as `"uuid"` is the same as that format.
        public static func other(_ format: String) -> Self {
            Self(jsonFormat: .other(format))
        }
    }
}
#endif
