#if OpenAPI
import OpenAPIKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension OpenAPIValue {
    /// The schema this value describes, and its example when it's a single `.example`.
    ///
    /// Combinations have no example, as in VaporToOpenAPI: merging their parts' examples rarely
    /// gives a value that matches.
    func schema(into components: inout SchemaComponents) throws -> (schema: JSONSchema, example: AnyCodable?) {
        // Inout changes survive a throw, so drop what earlier parts of a combination stored.
        let saved = components
        do {
            return try describe(into: &components)
        } catch {
            components = saved
            throw error
        }
    }

    private func describe(into components: inout SchemaComponents) throws -> (schema: JSONSchema, example: AnyCodable?) {
        switch self {
        case .type(let type):
            (try JSONSchema.decoded(type, into: &components), nil)
        case .example(let example):
            try JSONSchema.example(example, into: &components)
        case .allOf(let values):
            (try JSONSchema.all(of: Self.schemas(of: values, into: &components)), nil)
        case .anyOf(let values):
            (try JSONSchema.any(of: Self.schemas(of: values, into: &components)), nil)
        case .oneOf(let values):
            (try JSONSchema.one(of: Self.schemas(of: values, into: &components)), nil)
        case .not(let value):
            (try JSONSchema.not(value.schema(into: &components).schema), nil)
        }
    }

    /// One parameter per property of the object this value describes.
    ///
    /// `.allOf` concatenates its parts' parameters. A property's own example comes from an
    /// `.example`, and an optional property is a parameter that may be left out.
    func parameters(
        in location: ParameterLocation,
        into components: inout SchemaComponents
    ) throws -> [OpenAPI.Parameter] {
        switch self {
        case .allOf(let values):
            return try values.flatMap { value in
                try value.parameters(in: location, into: &components)
            }
        default:
            let (schema, example) = try schema(into: &components)
            guard let object = components.resolved(schema).objectContext else {
                throw ParametersError(type: describedType)
            }
            // Read the example's properties once, rather than once per parameter.
            let examples = example?.properties
            return object.properties.map { name, property in
                .parameter(
                    name: name,
                    location: location,
                    required: property.required,
                    schema: property,
                    example: examples?[name]
                )
            }
        }
    }

    /// The Swift type this value describes, if it's a single one.
    private var describedType: Any.Type? {
        switch self {
        case .type(let type): type
        case .example(let value): Swift.type(of: value)
        case .allOf, .anyOf, .oneOf, .not: nil
        }
    }

    private static func schemas(of values: [OpenAPIValue], into components: inout SchemaComponents) throws -> [JSONSchema] {
        try values.map {
            try $0.schema(into: &components).schema
        }
    }
}

/// Where parameters are sent.
enum ParameterLocation: Sendable {
    case query
    case header
    case path
    case cookie
}

extension SchemaComponents {
    /// The schema a component `$ref` points to, or `schema` itself when it isn't one.
    func resolved(_ schema: JSONSchema) -> JSONSchema {
        guard let name = schema.reference?.name,
            let key = OpenAPI.ComponentKey(rawValue: name),
            let stored = schemas[key]
        else { return schema }
        return stored
    }
}

extension AnyCodable {
    /// The values of this JSON object by key, or `nil` when it isn't an object.
    ///
    /// A round trip through JSON, since `value` is `Any` and only `Sendable` values can be wrapped.
    var properties: [String: AnyCodable]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode([String: AnyCodable].self, from: data)
    }
}

extension OpenAPI.Parameter {
    /// A parameter with its location's default style. Path parameters are always required.
    static func parameter(
        name: String,
        location: ParameterLocation,
        required: Bool,
        schema: JSONSchema,
        example: AnyCodable?
    ) -> Self {
        func context(_ location: Context.Location) -> Either<SchemaContext, OpenAPI.Content.Map> {
            .schema(SchemaContext(schema, style: .default(for: location), example: example))
        }
        switch location {
        case .query:
            return .init(name: name, context: .query(required: required, schemaOrContent: context(.query)))
        case .header:
            return .init(name: name, context: .header(required: required, schemaOrContent: context(.header)))
        case .path:
            return .init(name: name, context: .path(schemaOrContent: context(.path)))
        case .cookie:
            return .init(name: name, context: .cookie(required: required, schemaOrContent: context(.cookie)))
        }
    }
}

/// Parameters must come from an object, whose properties name them.
private struct ParametersError: Error, CustomStringConvertible {
    var type: Any.Type?
    var description: String {
        "Parameters must be described by an object, not \(type.map { "\($0)" } ?? "this schema")"
    }
}
#endif
