#if OpenAPI
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A compact rendering of a shape, so tests can compare it in one line.
///
/// Leaves are their type name, objects `{a: X, b?: Y}`, arrays `[X]`, dictionaries `[: X]`,
/// single values `(X)`, recursion `^X`, and a trailing `!` marks a nullable value.
private func render(_ shape: DecodedShape) -> String {
    let body: String
    switch shape.kind {
    case .leaf: body = "\(shape.type)"
    case .keyed(let fields):
        body = "{" + fields.map { "\($0.name)\($0.isOptional ? "?" : ""): \(render($0.shape))" }.joined(separator: ", ") + "}"
    case .dictionary(let value): body = "[: \(render(value))]"
    case .unkeyed(let element): body = "[\(element.map(render) ?? "")]"
    case .single(let value): body = "(\(render(value)))"
    case .recursive: body = "^\(shape.type)"
    case .empty: body = "empty"
    }
    return body + (shape.isNullable ? "!" : "")
}

private func shape<T: Decodable>(of type: T.Type) throws -> String {
    render(try SchemaDecoder.shape(of: type))
}

private struct Team: Decodable { var title: String }
private struct User: Decodable {
    var id: Int
    var nickname: String?
    var team: Team
    var manager: Team?
    var tags: [String]
    var createdAt: Date
}
private struct Email: Decodable {
    var value: String
    init(from decoder: any Decoder) throws {
        value = try decoder.singleValueContainer().decode(String.self)
    }
}
private struct Big: Decodable {
    var signed: Int128
    var unsigned: UInt128?
    var list: [Int128]
}
private struct Node: Decodable {
    var name: String
    var children: [Node]
}
private struct Branch: Decodable { var kids: [String: Branch] }
private struct Tag: Decodable, Hashable { var related: Set<Tag> }
private struct Holder: Decodable { var items: [Holder?] }
private final class Link: Decodable {
    var value: Int
    var next: Link?
}
private final class Loop: Decodable { let me: Loop }
private enum Role: String, Decodable, CaseIterable { case admin, user }
private enum Plain: String, Decodable { case only }
private enum Shape: Decodable { case circle(Double) }
private struct Account: Decodable {
    var role: Role
    var team: PlainTeam
}
private struct PlainTeam: Decodable { var plain: Plain }

private struct Parent: Decodable {
    var name: String
    var children: [Child]
}
private struct Child: Decodable {
    var parent: Parent
    var name: String
}
private final class First: Decodable { var second: Second? }
private final class Second: Decodable {
    let first: First
    let tag: Int
}
private final class Ping: Decodable { let pong: Pong }
private final class Pong: Decodable { let ping: Ping }
private struct Nothing: Decodable {}
private struct Silent: Decodable {
    init(from decoder: any Decoder) throws {}
}
private struct NoElements: Decodable {
    init(from decoder: any Decoder) throws {
        _ = try decoder.unkeyedContainer()
    }
}
private struct Nested: Decodable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .inner)
    }
    enum CodingKeys: String, CodingKey { case inner }
}
private enum Level: Int, Decodable, CaseIterable {
    case low = 1
    case high = 2
}
private struct Ranked: Decodable { var scores: [Role: Int] }
private struct Family: Decodable { var kids: [Kid] }
private struct Kid: Decodable {
    var family: Family
    var toys: [Toy]
}
private struct Toy: Decodable {
    var owner: Kid
    var name: String
}
private final class BinaryNode: Decodable {
    let value: Int
    let left: BinaryNode?
    let right: BinaryNode?
}
private indirect enum Expression: Decodable {
    case number(Int)
    case sum(Expression, Expression)
}

@Suite("Schema decoder")
struct SchemaDecoderTests {
    // MARK: - Values

    @Test("Builtin types are leaves")
    func leaves() throws {
        #expect(try shape(of: Int.self) == "Int")
        #expect(try shape(of: String.self) == "String")
        #expect(try shape(of: Date.self) == "Date")
        #expect(try shape(of: UUID.self) == "UUID")
    }

    @Test("Properties are recorded in order, with decodeIfPresent ones optional")
    func object() throws {
        #expect(
            try shape(of: User.self)
                == "{id: Int, nickname?: String, team: {title: String}, manager?: {title: String}, tags: [String], createdAt: Date}"
        )
    }

    @Test("128-bit integers are leaves, which the protocol defaults would otherwise reject")
    func bigIntegers() throws {
        #expect(try shape(of: Big.self) == "{signed: Int128, unsigned?: UInt128, list: [Int128]}")
    }

    @Test("Arrays and sets record their element")
    func arrays() throws {
        #expect(try shape(of: [Int].self) == "[Int]")
        #expect(try shape(of: [[Team]].self) == "[[{title: String}]]")
        #expect(try shape(of: Set<String>.self) == "[String]")
    }

    @Test("An optional is a nullable single value")
    func optional() throws {
        #expect(try shape(of: Int?.self) == "(Int)!")
        #expect(try shape(of: [Int?].self) == "[(Int)!]")
    }

    @Test("A single value wrapper records what it wraps")
    func wrapper() throws {
        #expect(try shape(of: Email.self) == "(String)")
    }

    @Test("Dictionaries record their value, with string or integer keys")
    func dictionaries() throws {
        #expect(try shape(of: [String: Int].self) == "[: Int]")
        #expect(try shape(of: [Int: Team].self) == "[: {title: String}]")
    }

    @Test("A CaseIterable enum is decoded from its first case")
    func caseIterable() throws {
        #expect(try shape(of: Role.self) == "(String)")
        #expect(try shape(of: [Role].self) == "[(String)]")
    }

    // MARK: - Recursion

    @Test("Recursion through an array is recorded and ended with an empty array")
    func recursiveArray() throws {
        #expect(try shape(of: Node.self) == "{name: String, children: [^Node]}")
        #expect(try shape(of: [Node].self) == "[{name: String, children: [^Node]}]")
    }

    @Test("Recursion through a dictionary or set is recorded too")
    func recursiveCollections() throws {
        #expect(try shape(of: Branch.self) == "{kids: [: ^Branch]}")
        #expect(try shape(of: Tag.self) == "{related: [^Tag]}")
    }

    @Test("Recursion through an optional is recorded and ended with nil")
    func recursiveOptional() throws {
        #expect(try shape(of: Link.self) == "{value: Int, next?: ^Link}")
        #expect(try shape(of: Holder.self) == "{items: [(^Holder)!]}")
    }

    // MARK: - Errors

    @Test("Recursion with no array or optional to end it is an error")
    func unbreakableRecursion() {
        #expect(throws: (any Error).self) { try SchemaDecoder.shape(of: Loop.self) }
        #expect(throws: (any Error).self) { try SchemaDecoder.shape(of: [Loop].self) }
    }

    @Test("A type that can't be decoded from placeholders names its path and suggests a fix")
    func errorMessage() throws {
        let error = try #require(throws: (any Error).self) { try SchemaDecoder.shape(of: Account.self) }
        let message = "\(error)"
        #expect(message.hasPrefix("team.plain: can't describe Plain, "))
        #expect(message.contains("Make it CaseIterable"))
        // Wrapped once, by the type that failed, not again by each type around it.
        #expect(message.ranges(of: "can't describe").count == 1)
    }

    @Test("An enum with associated values can't be described yet")
    func associatedValues() {
        #expect(throws: (any Error).self) { try SchemaDecoder.shape(of: Shape.self) }
    }
    // MARK: - Edge cases

    @Test("Mutual recursion ends at the array or optional around it, not at the type in between")
    func mutualRecursion() throws {
        // The type in between keeps the properties after the recursive one.
        #expect(try shape(of: Parent.self) == "{name: String, children: [{parent: ^Parent, name: String}]}")
        #expect(try shape(of: First.self) == "{second?: {first: ^First, tag: Int}}")
    }

    @Test("Recursion nested in recursion is decoded whole, however many runs it takes")
    func nestedMutualRecursion() throws {
        #expect(try shape(of: Family.self) == "{kids: [{family: ^Family, toys: [{owner: ^Kid, name: String}]}]}")
    }

    @Test("Mutual recursion with nothing to end it is an error")
    func unbreakableMutualRecursion() {
        #expect(throws: (any Error).self) { try SchemaDecoder.shape(of: Ping.self) }
    }

    @Test("A type that asks for no container is empty, as a synthesized empty struct does")
    func emptyTypes() throws {
        #expect(try shape(of: Nothing.self) == "empty")
        #expect(try shape(of: Silent.self) == "empty")
        #expect(try shape(of: NoElements.self) == "[]")
    }

    @Test("Optionals nest")
    func nestedOptionals() throws {
        #expect(try shape(of: Int??.self) == "((Int)!)!")
    }

    @Test("Integer enums are decoded from their first case too")
    func integerEnum() throws {
        #expect(try shape(of: Level.self) == "(Int)")
    }

    @Test("Unsupported containers and dictionary keys fail with their path")
    func unsupported() throws {
        let nested = try #require(throws: (any Error).self) { try SchemaDecoder.shape(of: Nested.self) }
        #expect("\(nested)".contains("Nested containers aren't supported"))
        let keyed = try #require(throws: (any Error).self) { try SchemaDecoder.shape(of: Ranked.self) }
        #expect("\(keyed)".hasPrefix("scores: "))
    }

    @Test("A binary tree refers to itself on both sides")
    func binaryTree() throws {
        #expect(try shape(of: BinaryNode.self) == "{value: Int, left?: ^BinaryNode, right?: ^BinaryNode}")
    }

    @Test("An indirect enum has associated values, so it can't be described yet")
    func indirectEnum() {
        #expect(throws: (any Error).self) { try SchemaDecoder.shape(of: Expression.self) }
    }

    @Test("The error suggests what will help")
    func errorHint() throws {
        let error = try #require(throws: (any Error).self) { try SchemaDecoder.shape(of: Plain.self) }
        #expect("\(error)".hasSuffix("or give it a `static var openAPIPlaceholder: Self?` through OpenAPISchemaProvider."))
        #expect(!"\(error)".contains(".."))
    }
}
#endif
