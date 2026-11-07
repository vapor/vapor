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
private struct Node {}
private struct Tree {}
private struct Parent {}
private struct Child {}
private struct Token {}

/// A second and third `User`, kept out of the way of the one above.
private func otherUser() -> Any.Type {
    struct User {}
    return User.self
}
private func thirdUser() -> Any.Type {
    struct User {}
    return User.self
}

private struct DescribeFailed: Error {}

private let userSchema = JSONSchema.object(properties: ["id": .integer])

@Suite("Schema components")
struct SchemaComponentsTests {
    @Test("An object is stored as a component and referred to")
    func storesObject() throws {
        var components = SchemaComponents()
        let schema = components.schema(for: User.self) { _ in userSchema }
        #expect(schema == ref("User"))
        #expect(components.schemas == ["User": userSchema])
    }

    @Test("A type is described once and referred to after that")
    func describesOnce() {
        var components = SchemaComponents()
        var calls = 0
        for _ in 0..<3 {
            let schema = components.schema(for: User.self) { _ in
                calls += 1
                return userSchema
            }
            #expect(schema == ref("User"))
        }
        #expect(calls == 1)
        #expect(components.schemas.count == 1)
    }

    @Test("A schema that isn't worth a component stays inline, and its name stays free")
    func inline() {
        var components = SchemaComponents()
        #expect(components.schema(for: Token.self) { _ in .string } == .string)
        #expect(components.schemas.isEmpty)

        // The name is free, and the type is described afresh.
        #expect(components.schema(for: Token.self) { _ in userSchema } == ref("Token"))
    }

    @Test("Different types with the same name get numbered names")
    func collisions() {
        var components = SchemaComponents()
        #expect(components.schema(for: User.self) { _ in userSchema } == ref("User"))
        #expect(components.schema(for: otherUser()) { _ in userSchema } == ref("User2"))
        #expect(components.schema(for: thirdUser()) { _ in userSchema } == ref("User3"))
        #expect(components.schema(for: otherUser()) { _ in .string } == ref("User2"))
        #expect(components.schemas.keys.map(\.rawValue) == ["User", "User2", "User3"])
    }

    @Test("A name reserved by a type still being described isn't given to another")
    func collisionWhileDescribing() {
        var components = SchemaComponents()
        let schema = components.schema(for: User.self) { components in
            .object(properties: ["other": components.schema(for: otherUser()) { _ in userSchema }])
        }
        #expect(schema == ref("User"))
        #expect(components.schemas["User"] == .object(properties: ["other": ref("User2")]))
        #expect(components.schemas["User2"] == userSchema)
    }

    @Test("A recursive type refers to itself")
    func recursion() throws {
        var components = SchemaComponents()
        let schema = components.schema(for: Node.self) { components in
            .object(properties: ["children": .array(items: components.schema(for: Node.self) { _ in .string })])
        }
        #expect(schema == ref("Node"))
        let node = try #require(components.schemas["Node"])
        #expect(
            try json(node)
                == ##"{"properties":{"children":{"items":{"$ref":"#/components/schemas/Node"},"type":"array"}},"required":["children"],"type":"object"}"##
        )
    }

    @Test("A recursive schema is stored even when it wouldn't be otherwise, so its $ref resolves")
    func recursiveInline() {
        var components = SchemaComponents()
        let schema = components.schema(for: Tree.self) { components in
            .array(items: components.schema(for: Tree.self) { _ in .string })
        }
        #expect(schema == ref("Tree"))
        #expect(components.schemas["Tree"] == .array(items: ref("Tree")))
    }

    @Test("Nested types are stored before the type that contains them")
    func order() {
        var components = SchemaComponents()
        _ = components.schema(for: Parent.self) { components in
            .object(properties: ["child": components.schema(for: Child.self) { _ in userSchema }])
        }
        #expect(components.schemas.keys.map(\.rawValue) == ["Child", "Parent"])
    }

    @Test("If describing throws, nothing it added is kept")
    func throwingDescribe() throws {
        var components = SchemaComponents()
        #expect(throws: DescribeFailed.self) {
            try components.schema(for: Parent.self) { components in
                // The child refers back to the parent, so it can't be kept alone.
                _ = components.schema(for: Child.self) { components in
                    .object(properties: ["parent": components.schema(for: Parent.self) { _ in .string }])
                }
                throw DescribeFailed()
            }
        }
        #expect(components == SchemaComponents())

        // The parent's name isn't left reserved.
        #expect(components.schema(for: Parent.self) { _ in userSchema } == ref("Parent"))
        #expect(components.schemas.keys.map(\.rawValue) == ["Parent"])
    }
}
#endif
