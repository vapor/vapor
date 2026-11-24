#if OpenAPI
import OpenAPIKit
import Vapor
@testable import VaporOpenAPI
import VaporTesting

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The info most tests build their document with.
let petsInfo = OpenAPIInfo(title: "Pets", version: "1.0.0")

/// The value as compact JSON with sorted keys, so tests can compare it exactly.
func json(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
}

/// The schema as compact JSON with sorted keys.
func json(_ schema: OpenAPISchema) throws -> String {
    try json(schema.schema)
}

/// A `$ref` to the schema component called `name`.
func ref(_ name: String) -> JSONSchema {
    .reference(.component(named: name))
}

/// The document for the routes `configure` registers, checked by OpenAPIKit's validator.
func document(_ configure: (Application) throws -> Void) async throws -> OpenAPI.Document {
    try await withApp { app in
        try configure(app)
        let document = try app.routes.openAPI(info: petsInfo).document
        _ = try document.validate()
        return document
    }
}
#endif
