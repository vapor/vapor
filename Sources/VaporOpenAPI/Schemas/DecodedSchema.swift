#if OpenAPI
import OpenAPIKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension JSONSchema {
    /// The schema for values of `type`, worked out from what its `init(from:)` decodes.
    ///
    /// Objects and enums are stored in `components` and referred to by `$ref`.
    static func decoded<T: Decodable>(_ type: T.Type, into components: inout SchemaComponents) throws -> JSONSchema {
        // A type that describes itself needn't decode at all, so its `init(from:)` can reject placeholders.
        if let known = JSONSchema.schema(for: type) {
            return components.schema(for: type) { _ in known }
        }
        // Decoding runs the type's `init(from:)` and its nested types' again, so a type already
        // stored is only referred to.
        if let stored = components.reference(to: type) {
            return stored
        }
        return schema(for: try SchemaDecoder.shape(of: type), into: &components)
    }

    private static func schema(for shape: DecodedShape, into components: inout SchemaComponents) -> JSONSchema {
        let schema = namedSchema(for: shape, into: &components)
        return shape.isNullable ? schema.allowingNull() : schema
    }

    /// The schema for `shape`, through `components` unless its type only wraps another.
    private static func namedSchema(for shape: DecodedShape, into components: inout SchemaComponents) -> JSONSchema {
        // A provider or builtin schema wins over the decoded structure: `Date` decodes a `Double`.
        if let known = JSONSchema.schema(for: shape.type) {
            return components.schema(for: shape.type) { _ in known }
        }
        if let enumeration = enumeration(of: shape) {
            return components.schema(for: shape.type) { _ in enumeration }
        }
        if SchemaDecoder.canBeEmpty(shape.type) {
            return structure(of: shape, into: &components)
        }
        return components.schema(for: shape.type) { components in structure(of: shape, into: &components) }
    }

    private static func structure(of shape: DecodedShape, into components: inout SchemaComponents) -> JSONSchema {
        switch shape.kind {
        case .keyed(let fields):
            var properties: OrderedDictionary<String, JSONSchema> = [:]
            for field in fields {
                let property = schema(for: field.shape, into: &components)
                properties[field.name] = field.isOptional ? property.optionalSchemaObject() : property
            }
            return .object(properties: properties)
        case .dictionary(let value):
            return .object(additionalProperties: .b(schema(for: value, into: &components)))
        case .unkeyed(let element):
            return .array(items: element.map { schema(for: $0, into: &components) })
        case .single(let value):
            return schema(for: value, into: &components)
        case .recursive:
            // The type is still being described further up, so `components` has already answered with a `$ref`.
            assertionFailure("\(shape.type) is recursive but isn't being described")
            return .fragment
        case .leaf, .empty:
            // Every leaf has a builtin schema; a type that decodes nothing can be any value.
            return .fragment
        }
    }

    /// The cases of a `CaseIterable` enum, or `nil` for any other type.
    ///
    /// Raw values give a string or integer enum. Without them, the synthesized coding is an object
    /// keyed by the case, such as `{"on": {}}`; that needs the enum to be `Encodable` to read the keys.
    private static func enumeration(of shape: DecodedShape) -> JSONSchema? {
        guard let cases = shape.type as? any CaseIterable.Type else { return nil }
        let rawValues = rawValues(of: cases)
        if let strings = rawValues as? [String], !strings.isEmpty {
            return .string(allowedValues: strings.map { AnyCodable($0) })
        }
        if let integers = rawValues as? [Int], !integers.isEmpty {
            return .integer(allowedValues: integers.map { AnyCodable($0) })
        }
        // Only an empty keyed shape is the synthesized coding; anything else is the type's own.
        if rawValues.isEmpty, case .keyed(let fields) = shape.kind, fields.isEmpty,
            let names = caseKeys(of: cases), !names.isEmpty
        {
            return .one(of: names.map { .object(properties: [$0: .object]) })
        }
        return nil
    }

    /// The key each case is encoded under, read back from encoding it so renamed `CodingKeys` count.
    private static func caseKeys<C: CaseIterable>(of type: C.Type) -> [String]? {
        guard C.self is any Encodable.Type else { return nil }
        var keys: [String] = []
        for value in C.allCases {
            guard let encodable = value as? any Encodable,
                let data = try? JSONEncoder().encode(encodable),
                let object = try? JSONDecoder().decode([String: [String: Int]].self, from: data),
                let key = object.keys.first, object.count == 1
            else { return nil }
            keys.append(key)
        }
        return keys
    }

    private static func rawValues<C: CaseIterable>(of type: C.Type) -> [Any] {
        C.allCases.compactMap { ($0 as? any RawRepresentable)?.rawValue }
    }
}

#endif
