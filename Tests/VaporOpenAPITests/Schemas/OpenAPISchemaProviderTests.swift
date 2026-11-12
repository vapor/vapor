#if OpenAPI
import OpenAPIKit
import Testing
// Public, because conforming the public `Decimal` below makes a public conformance.
@testable public import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The schema a generic caller sees, which goes through the protocol witness.
private func genericSchema<T: OpenAPISchemaProvider>(_: T.Type) -> OpenAPISchema {
    T.openAPISchema
}

private enum Role: String, Codable, CaseIterable, OpenAPISchemaProvider {
    case user
    case admin
}

/// A string-backed enum that describes itself rather than taking the default.
private enum Color: String, CaseIterable, OpenAPISchemaProvider {
    case red
    case green

    static var openAPISchema: OpenAPISchema { .string(format: .other("color")) }
}

private struct Money: OpenAPISchemaProvider {
    static var openAPISchema: OpenAPISchema { .object(["amount": .string(), "currency": .string()]) }
}

/// String-backed and `CaseIterable`, but with no cases. An enum with no cases can't have a raw type.
private struct NoCases: RawRepresentable, CaseIterable, OpenAPISchemaProvider {
    var rawValue: String
    static var allCases: [NoCases] { [] }
}

private struct User: Codable {
    var id: Int
}

// WARNING: conformances are global, so this changes `Decimal` for EVERY test in the process, not
// just this file's. Anything that describes a `Decimal` through `schema(for:)`, such as a body
// or a property of a decoded type, gets `{"type":"string"}` here instead of the builtin number.
// Don't describe a `Decimal` in any other test. Only `builtin(for:)` and `Placeholder` are
// unaffected, since they don't look at providers.
extension Decimal: OpenAPISchemaProvider {
    static var openAPISchema: OpenAPISchema { .string() }
}

@Suite("OpenAPISchemaProvider")
struct OpenAPISchemaProviderTests {
    // MARK: - String enums

    @Test("A string enum is described by its raw values, in declaration order, including in generic code")
    func enumDefault() throws {
        #expect(try json(Role.openAPISchema.schema) == #"{"enum":["user","admin"],"type":"string"}"#)
        #expect(genericSchema(Role.self) == .enumeration(["user", "admin"]))
    }

    @Test("A type with no cases is rejected")
    func noCasesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = NoCases.openAPISchema
        }
    }

    @Test("A type's own schema replaces the enum default, including in generic code")
    func customBeatsDefault() throws {
        let expected = #"{"format":"color","type":"string"}"#
        #expect(try json(Color.openAPISchema.schema) == expected)
        #expect(try json(genericSchema(Color.self).schema) == expected)
        let found = try #require(JSONSchema.schema(for: Color.self))
        #expect(try json(found) == expected)
    }

    // MARK: - schema(for:)

    @Test("A provider's schema is found from its metatype")
    func schemaForProvider() throws {
        let role = try #require(JSONSchema.schema(for: Role.self))
        let money = try #require(JSONSchema.schema(for: Money.self))
        #expect(try json(role) == json(Role.openAPISchema.schema))
        #expect(try json(money) == json(Money.openAPISchema.schema))
    }

    @Test("A provider takes precedence over the builtin schema")
    func providerBeatsBuiltin() throws {
        let provided = try #require(JSONSchema.schema(for: Decimal.self))
        let builtin = try #require(JSONSchema.builtin(for: Decimal.self))
        #expect(try json(provided) == #"{"type":"string"}"#)
        #expect(try json(builtin) == #"{"type":"number"}"#)
    }

    @Test("Without a provider the builtin schema is used, and a type with neither, or a container, has none")
    func schemaFallbacks() throws {
        let string = try #require(JSONSchema.schema(for: String.self))
        let uuid = try #require(JSONSchema.schema(for: UUID.self))
        #expect(try json(string) == #"{"type":"string"}"#)
        #expect(try json(uuid) == #"{"format":"uuid","type":"string"}"#)
        #expect(JSONSchema.schema(for: User.self) == nil)
        // Containers of providers aren't resolved here.
        #expect(JSONSchema.schema(for: Role?.self) == nil)
        #expect(JSONSchema.schema(for: [Role].self) == nil)
        #expect(JSONSchema.schema(for: [String: Role].self) == nil)
    }
}
#endif
