#if OpenAPI
import OpenAPIKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension JSONSchema {
    /// The schema for `value`'s type, and `value` itself as its JSON example.
    ///
    /// The schema comes from a provider or builtin first, so those types needn't be `Decodable`;
    /// any other type is described by ``decoded(_:into:)``.
    static func example(
        _ value: some Encodable,
        into components: inout SchemaComponents
    ) throws -> (schema: JSONSchema, example: AnyCodable) {
        // ISO 8601, as Vapor encodes content by default and as the builtin `date-time` schema says.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let example = try JSONDecoder().decode(AnyCodable.self, from: data)
        let valueType = type(of: value)

        // A provider or builtin schema needs no Decodable conformance.
        if let known = JSONSchema.schema(for: valueType) {
            return (components.schema(for: valueType) { _ in known }, example)
        }
        guard let decodableType = valueType as? any Decodable.Type else {
            throw EncodableOnlyError(type: valueType)
        }
        let jsonSchema = try JSONSchema.decoded(decodableType, into: &components)
        return (schema: jsonSchema, example: example)
    }
}

/// The example's type has no schema of its own and can't be decoded to work one out.
private struct EncodableOnlyError: Error, CustomStringConvertible {
    var type: Any.Type
    var description: String { "\(type) is only Encodable; make it Decodable, or describe it with OpenAPISchemaProvider" }
}

#endif
