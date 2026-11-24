#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private struct User {}
struct InternalUser {}
private enum Outer {
    struct Inner {}
}
private struct Page<Item> {
    struct Cursor {
        struct Deep {}
    }
}
private struct Pair<First, Second> {}
// Non-ASCII names are valid Swift but not valid component keys.
private struct Користувач {}

/// A local type with only the module around it.
private func localType() -> Any.Type {
    struct Local {}
    return Local.self
}

@Suite("Schema references")
struct SchemaReferencesTests {
    // MARK: - Component names

    @Test(
        "A component is named like the type in code, without its module",
        arguments: [
            (User.self as Any.Type, "User"),
            (InternalUser.self, "InternalUser"),
            (Outer.Inner.self, "Outer.Inner"),
            (Page<User>.self, "PageUser"),
            (Page<Outer.Inner>.self, "PageOuter.Inner"),
            (Page<[User]>.self, "PageArrayUser"),
            (Page<User?>.self, "PageOptionalUser"),
            (Page<[String: Int]>.self, "PageDictionaryStringInt"),
            (Pair<User, Int>.self, "PairUserInt"),
            (Page<User>.Cursor.self, "PageUserCursor"),
            (Page<User>.Cursor.Deep.self, "PageUserCursor.Deep"),
            (String.self, "String"),
        ]
    )
    func names(type: Any.Type, expected: String) {
        #expect(JSONSchema.componentName(for: type) == expected)
    }

    @Test("A local type is named without its unknown contexts, but keeps the types around it")
    func localTypes() {
        struct Local {}
        #expect(JSONSchema.componentName(for: localType()) == "Local")
        #expect(JSONSchema.componentName(for: Local.self) == "SchemaReferencesTests.Local")
        #expect(JSONSchema.componentName(for: Page<Local>.self) == "PageSchemaReferencesTests.Local")
    }

    @Test("Characters that aren't allowed in a component key are replaced")
    func unsafeCharacters() {
        let name = JSONSchema.componentName(for: Користувач.self)
        #expect(name == String(repeating: "-", count: "Користувач".count))
    }

    // MARK: - Referenceable

    @Test(
        "Named shapes and compositions are stored as components",
        arguments: [
            OpenAPISchema.object(["id": .integer()]).schema,
            OpenAPISchema.object().schema,
            OpenAPISchema.enumeration(["admin", "user"]).schema,
            OpenAPISchema.enumeration(["admin"]).schema,
            OpenAPISchema.enumeration(["admin"]).nullable().schema,
            // An object that forbids extra properties is a named shape.
            JSONSchema.object(additionalProperties: .a(false)),
            JSONSchema.all(of: [.string, .integer]),
            JSONSchema.one(of: [.string, .integer]),
            JSONSchema.any(of: [.string, .integer]),
            JSONSchema.not(.string),
        ]
    )
    func referenceable(schema: JSONSchema) {
        #expect(schema.isReferenceable)
    }

    @Test(
        "Primitives, arrays, dictionaries and references stay inline",
        arguments: [
            OpenAPISchema.string().schema,
            OpenAPISchema.string(format: .uuid).schema,
            OpenAPISchema.integer().schema,
            OpenAPISchema.number().schema,
            OpenAPISchema.boolean.schema,
            OpenAPISchema.array(of: .object(["id": .integer()])).schema,
            OpenAPISchema.dictionary(of: .string()).schema,
            // An object that allows any extra properties is a dictionary.
            JSONSchema.object(additionalProperties: .a(true)),
            // A reference is already a reference.
            ref("User"),
        ]
    )
    func inline(schema: JSONSchema) {
        #expect(!schema.isReferenceable)
    }

    // MARK: - Allowing null

    @Test("A reference allows null through anyOf, keeping its description and staying optional in an object")
    func nullableReference() throws {
        let reference = JSONSchema.reference(.component(named: "User"), required: false, description: "The manager")
        let schema = reference.allowingNull()
        #expect(!schema.required)
        #expect(
            try json(schema)
                == ##"{"anyOf":[{"$ref":"#/components/schemas/User"},{"type":"null"}],"description":"The manager"}"##
        )
    }

    @Test("Allowing null twice is the same as once")
    func nullableIsIdempotent() throws {
        let enumeration = OpenAPISchema.enumeration(["admin"]).schema
        let composition = JSONSchema.one(of: [.string, .integer])
        for schema in [JSONSchema.string, enumeration, ref("User"), composition] {
            #expect(try json(schema.allowingNull().allowingNull()) == json(schema.allowingNull()))
        }
    }

    @Test("A composition allows null through anyOf, since a type next to it would only allow null")
    func nullableComposition() throws {
        let schema = JSONSchema.one(of: .string, .integer, required: false).allowingNull()
        #expect(!schema.required)
        #expect(
            try json(schema)
                == #"{"anyOf":[{"oneOf":[{"type":"string"},{"type":"integer"}]},{"type":"null"}]}"#
        )
    }
}
#endif
