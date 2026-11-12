#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The schema for `type` and the components it stored, as JSON.
private func decoded<T: Decodable>(_ type: T.Type) throws -> (schema: String, components: [String: String]) {
    var components = SchemaComponents()
    let schema = try JSONSchema.decoded(type, into: &components)
    var stored: [String: String] = [:]
    for (key, value) in components.schemas {
        stored[key.rawValue] = try json(value)
    }
    return (try json(schema), stored)
}

private struct Team: Decodable { var title: String }
private struct User: Decodable {
    var id: UUID
    var nickname: String?
    var team: Team
    var tags: [String]
}
private enum Role: String, Decodable, CaseIterable { case admin, user }
private enum Level: Int, Decodable, CaseIterable {
    case low = 1
    case high = 2
}
private struct Member: Decodable {
    var role: Role
    var backup: Role?
    var level: Level
}
private struct Email: Decodable {
    var value: String
    init(from decoder: any Decoder) throws {
        value = try decoder.singleValueContainer().decode(String.self)
    }
}
private struct Contact: Decodable {
    var email: Email
    var scores: [String: Int]
}

/// Seconds since 1970, as an app might encode it instead of ISO 8601.
private struct Timestamp: Decodable, OpenAPISchemaProvider {
    var seconds: Double
    static var openAPISchema: OpenAPISchema { .number(format: .double) }
}
/// A day such as `2026-10-28`, which rejects the empty placeholder string.
private struct Strict: Decodable, OpenAPISchemaProvider {
    init(from decoder: any Decoder) throws {
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not a day"))
    }
    static var openAPISchema: OpenAPISchema { .string(format: .date) }
}
private struct Event: Decodable { var at: Timestamp }

private struct Parent: Decodable { var children: [Child] }
private struct Child: Decodable {
    var parent: Parent
    var name: String
}
private struct Nothing: Decodable {}
private enum Switch: Codable, CaseIterable, CustomStringConvertible {
    case on
    case off
    // Neither the description nor the case name is what goes on the wire.
    var description: String { "switch" }
    enum CodingKeys: String, CodingKey {
        case on = "ON"
        case off = "OFF"
    }
}
/// A `CaseIterable` type that decodes real properties keeps its object schema.
private struct Plan: Decodable, CaseIterable {
    var name: String
    static var allCases: [Plan] { [Plan(name: "free")] }
}
private struct Tree: Decodable { var kids: [Tree?] }
/// Rejects placeholders, so it can only be described at the root, where it isn't decoded.
private enum Plain: String, Decodable, OpenAPISchemaProvider {
    case only
    static var openAPISchema: OpenAPISchema { .enumeration(["only"]) }
}
private struct HoldsPlain: Decodable { var plain: Plain }
/// Described by hand, with a placeholder so it can be a property of a decoded type.
private enum Shape: Codable, OpenAPISchemaProvider {
    case circle(radius: Double)
    case square(side: Double)
    static var openAPISchema: OpenAPISchema {
        .one(
            of: .object(["circle": .object(["radius": .number()])]),
            .object(["square": .object(["side": .number()])])
        )
    }
    static var openAPIPlaceholder: Shape? { .circle(radius: 0) }
}
private struct Drawing: Codable {
    var title: String
    var shape: Shape
    var outline: Shape?
}

@Suite("Decoded schemas")
struct DecodedSchemaTests {
    @Test("Builtin types stay inline")
    func builtin() throws {
        let result = try decoded(Int.self)
        #expect(result.schema == #"{"format":"int64","type":"integer"}"#)
        #expect(result.components.isEmpty)
    }

    @Test("Objects are stored as components, with optional properties left out of required")
    func object() throws {
        let result = try decoded(User.self)
        #expect(result.schema == ##"{"$ref":"#/components/schemas/User"}"##)
        #expect(
            result.components["User"]
                == ##"{"properties":{"id":{"format":"uuid","type":"string"},"nickname":{"type":"string"},"tags":{"items":{"type":"string"},"type":"array"},"team":{"$ref":"#/components/schemas/Team"}},"required":["id","team","tags"],"type":"object"}"##
        )
        #expect(result.components["Team"] == #"{"properties":{"title":{"type":"string"}},"required":["title"],"type":"object"}"#)
    }

    @Test("Arrays and dictionaries stay inline around what they hold")
    func containers() throws {
        #expect(try decoded([Team].self).schema == ##"{"items":{"$ref":"#/components/schemas/Team"},"type":"array"}"##)
        #expect(try decoded([String: Int].self).schema == #"{"additionalProperties":{"format":"int64","type":"integer"},"type":"object"}"#)
    }

    @Test("Optionals allow null once, through anyOf for a reference")
    func optionals() throws {
        #expect(try decoded(Int?.self).schema == #"{"format":"int64","type":["integer","null"]}"#)
        #expect(try decoded(Int??.self).schema == #"{"format":"int64","type":["integer","null"]}"#)
        #expect(try decoded(Team?.self).schema == ##"{"anyOf":[{"$ref":"#/components/schemas/Team"},{"type":"null"}]}"##)
    }

    @Test("CaseIterable enums are stored as enums of their raw values")
    func enums() throws {
        let result = try decoded(Member.self)
        #expect(result.components["Role"] == #"{"enum":["admin","user"],"type":"string"}"#)
        #expect(result.components["Level"] == #"{"enum":[1,2],"type":"integer"}"#)
        #expect(
            result.components["Member"]
                == ##"{"properties":{"backup":{"$ref":"#/components/schemas/Role"},"level":{"$ref":"#/components/schemas/Level"},"role":{"$ref":"#/components/schemas/Role"}},"required":["role","level"],"type":"object"}"##
        )
    }

    @Test("A single value wrapper is described inline by what it wraps")
    func wrapper() throws {
        let result = try decoded(Contact.self)
        #expect(result.components["Email"] == nil)
        #expect(
            result.components["Contact"]
                == #"{"properties":{"email":{"type":"string"},"scores":{"additionalProperties":{"format":"int64","type":"integer"},"type":"object"}},"required":["email","scores"],"type":"object"}"#
        )
    }

    @Test("A provider's schema wins over the structure it decodes")
    func provider() throws {
        let result = try decoded(Event.self)
        #expect(
            result.components["Event"] == #"{"properties":{"at":{"format":"double","type":"number"}},"required":["at"],"type":"object"}"#)
        #expect(result.components["Timestamp"] == nil)
    }

    @Test("A provider isn't decoded, so its init(from:) may reject placeholder values")
    func providerIsNotDecoded() throws {
        let result = try decoded(Strict.self)
        #expect(result.schema == #"{"format":"date","type":"string"}"#)
    }

    @Test("Mutually recursive types refer to each other's components")
    func mutualRecursion() throws {
        let result = try decoded(Parent.self)
        #expect(
            result.components["Parent"]
                == ##"{"properties":{"children":{"items":{"$ref":"#/components/schemas/Child"},"type":"array"}},"required":["children"],"type":"object"}"##
        )
        #expect(
            result.components["Child"]
                == ##"{"properties":{"name":{"type":"string"},"parent":{"$ref":"#/components/schemas/Parent"}},"required":["parent","name"],"type":"object"}"##
        )
    }

    @Test("Recursion through an optional element allows null in the array")
    func recursiveOptionalElement() throws {
        let result = try decoded(Tree.self)
        #expect(
            result.components["Tree"]
                == ##"{"properties":{"kids":{"items":{"anyOf":[{"$ref":"#/components/schemas/Tree"},{"type":"null"}]},"type":"array"}},"required":["kids"],"type":"object"}"##
        )
    }

    @Test("An enum without raw values is one of its case names as a key, as Codable synthesizes it")
    func enumWithoutRawValues() throws {
        #expect(
            try decoded(Switch.self).components["Switch"]
                == #"{"oneOf":[{"properties":{"ON":{"type":"object"}},"required":["ON"],"type":"object"},{"properties":{"OFF":{"type":"object"}},"required":["OFF"],"type":"object"}]}"#
        )
    }

    @Test("A CaseIterable type that decodes properties is an object, not an enum")
    func caseIterableStruct() throws {
        #expect(
            try decoded(Plan.self).components["Plan"] == #"{"properties":{"name":{"type":"string"}},"required":["name"],"type":"object"}"#)
    }

    @Test("A type that decodes nothing can be any value")
    func empty() throws {
        #expect(try decoded(Nothing.self).schema == "{}")
    }

    @Test("A provider that rejects placeholders works at the root but not inside another type")
    func strictProviderNested() throws {
        #expect(try decoded(Plain.self).schema == ##"{"$ref":"#/components/schemas/Plain"}"##)
        #expect(throws: (any Error).self) { try decoded(HoldsPlain.self) }
    }

    @Test("A provider's placeholder lets it be a property, as for an enum with associated values")
    func providerPlaceholder() throws {
        let result = try decoded(Drawing.self)
        #expect(
            result.components["Drawing"]
                == ##"{"properties":{"outline":{"$ref":"#/components/schemas/Shape"},"shape":{"$ref":"#/components/schemas/Shape"},"title":{"type":"string"}},"required":["title","shape"],"type":"object"}"##
        )
        #expect(result.components["Shape"]?.hasPrefix(#"{"oneOf":["#) == true)
    }
}
#endif
