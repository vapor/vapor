#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The schema as compact JSON with sorted keys, so tests can compare it exactly.
private func json(_ schema: OpenAPISchema) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(schema.schema), as: UTF8.self)
}

@Suite("OpenAPISchema")
struct OpenAPISchemaTests {
    // MARK: - Primitives

    @Test(
        "Primitive factories encode to their JSON Schema types",
        arguments: [
            (OpenAPISchema.string(), #"{"type":"string"}"#),
            (.integer(), #"{"type":"integer"}"#),
            (.number(), #"{"type":"number"}"#),
            (.boolean, #"{"type":"boolean"}"#),
        ]
    )
    func primitives(schema: OpenAPISchema, expected: String) throws {
        #expect(try json(schema) == expected)
    }

    @Test(
        "String formats encode as their JSON Schema names",
        arguments: [
            (OpenAPISchema.StringFormat.date, "date"),
            (.dateTime, "date-time"),
            (.time, "time"),
            (.duration, "duration"),
            (.email, "email"),
            (.idnEmail, "idn-email"),
            (.hostname, "hostname"),
            (.idnHostname, "idn-hostname"),
            (.ipv4, "ipv4"),
            (.ipv6, "ipv6"),
            (.uri, "uri"),
            (.uriReference, "uri-reference"),
            (.uriTemplate, "uri-template"),
            (.iri, "iri"),
            (.iriReference, "iri-reference"),
            (.uuid, "uuid"),
            (.jsonPointer, "json-pointer"),
            (.relativeJsonPointer, "relative-json-pointer"),
            (.regex, "regex"),
            (.password, "password"),
            (.other("phone"), "phone"),
        ]
    )
    func stringFormats(format: OpenAPISchema.StringFormat, name: String) throws {
        #expect(try json(.string(format: format)) == #"{"format":"\#(name)","type":"string"}"#)
    }

    @Test(
        "Integer formats encode as their JSON Schema names",
        arguments: [
            (OpenAPISchema.IntegerFormat.int32, "int32"),
            (.int64, "int64"),
            (.other("uint8"), "uint8"),
        ]
    )
    func integerFormats(format: OpenAPISchema.IntegerFormat, name: String) throws {
        #expect(try json(.integer(format: format)) == #"{"format":"\#(name)","type":"integer"}"#)
    }

    @Test(
        "Number formats encode as their JSON Schema names",
        arguments: [
            (OpenAPISchema.NumberFormat.float, "float"),
            (.double, "double"),
            (.other("decimal"), "decimal"),
        ]
    )
    func numberFormats(format: OpenAPISchema.NumberFormat, name: String) throws {
        #expect(try json(.number(format: format)) == #"{"format":"\#(name)","type":"number"}"#)
    }

    @Test("A nil format is the same as no format")
    func nilFormat() throws {
        #expect(try json(.string(format: nil)) == json(.string()))
        #expect(try json(.integer(format: nil)) == json(.integer()))
        #expect(try json(.number(format: nil)) == json(.number()))
    }

    @Test("Formats compare by value")
    func formatEquality() {
        #expect(OpenAPISchema.StringFormat.uuid == .uuid)
        #expect(OpenAPISchema.StringFormat.uuid != .date)
        #expect(OpenAPISchema.StringFormat.other("phone") == .other("phone"))
        #expect(OpenAPISchema.StringFormat.other("phone") != .other("fax"))
    }

    @Test("An empty custom format is the same as no format")
    func emptyOtherFormat() throws {
        #expect(try json(.string(format: .other(""))) == #"{"type":"string"}"#)
        #expect(try json(.integer(format: .other(""))) == #"{"type":"integer"}"#)
        #expect(try json(.number(format: .other(""))) == #"{"type":"number"}"#)
        #expect(OpenAPISchema.string(format: .other("")) == .string())
    }

    @Test("A custom format with a listed name is the same as that format")
    func otherMatchingListedFormat() throws {
        #expect(OpenAPISchema.StringFormat.other("uuid") == .uuid)
        #expect(OpenAPISchema.IntegerFormat.other("int64") == .int64)
        #expect(OpenAPISchema.NumberFormat.other("double") == .double)
        #expect(try json(.string(format: .other("uuid"))) == json(.string(format: .uuid)))
    }

    // MARK: - Containers

    @Test("An array lists the schema of its items")
    func array() throws {
        #expect(try json(.array(of: .string())) == #"{"items":{"type":"string"},"type":"array"}"#)
    }

    @Test("Arrays nest")
    func nestedArray() throws {
        #expect(
            try json(.array(of: .array(of: .integer())))
                == #"{"items":{"items":{"type":"integer"},"type":"array"},"type":"array"}"#
        )
    }

    @Test("An object with no properties is a plain object")
    func emptyObject() throws {
        #expect(try json(.object()) == #"{"type":"object"}"#)
        #expect(try json(.object([:])) == #"{"type":"object"}"#)
    }

    @Test("Object properties are required unless marked optional, in the order they're listed")
    func objectRequired() throws {
        let schema = OpenAPISchema.object([
            "id": .string(format: .uuid),
            "nickname": .string().optional(),
            "age": .integer(),
        ])
        #expect(
            try json(schema)
                == #"{"properties":{"age":{"type":"integer"},"id":{"format":"uuid","type":"string"},"nickname":{"type":"string"}},"required":["id","age"],"type":"object"}"#
        )
    }

    @Test("An object whose properties are all optional has no required list")
    func allOptional() throws {
        let schema = OpenAPISchema.object(["a": .string().optional(), "b": .integer().optional()])
        #expect(!(try json(schema).contains("required")))
    }

    @Test("A repeated property name keeps the last schema")
    func duplicateProperty() throws {
        let schema = OpenAPISchema.object(["a": .string(), "a": .integer()])
        #expect(try json(schema) == #"{"properties":{"a":{"type":"integer"}},"required":["a"],"type":"object"}"#)
    }

    @Test("Objects nest")
    func nestedObject() throws {
        let schema = OpenAPISchema.object(["owner": .object(["name": .string()])])
        #expect(
            try json(schema)
                == #"{"properties":{"owner":{"properties":{"name":{"type":"string"}},"required":["name"],"type":"object"}},"required":["owner"],"type":"object"}"#
        )
    }

    @Test("A dictionary describes its values as additional properties")
    func dictionary() throws {
        #expect(try json(.dictionary(of: .integer())) == #"{"additionalProperties":{"type":"integer"},"type":"object"}"#)
    }

    @Test("An enumeration is a string limited to its values, in order")
    func enumeration() throws {
        #expect(try json(.enumeration(["b", "a"])) == #"{"enum":["b","a"],"type":"string"}"#)
    }

    // MARK: - Modifiers

    @Test("Nullable adds null to the type, as in OpenAPI 3.1")
    func nullable() throws {
        #expect(try json(.string().nullable()) == #"{"type":["string","null"]}"#)
    }

    @Test("Optional only matters inside an object")
    func optionalOnItsOwn() throws {
        #expect(try json(.string().optional()) == json(.string()))
    }

    @Test("Optional and nullable can be combined")
    func optionalAndNullable() throws {
        let schema = OpenAPISchema.object(["nickname": .string().optional().nullable()])
        #expect(try json(schema) == #"{"properties":{"nickname":{"type":["string","null"]}},"type":"object"}"#)
    }

    @Test("A description is shown alongside the type")
    func description() throws {
        #expect(try json(.string().description("The user's name")) == #"{"description":"The user's name","type":"string"}"#)
    }

    @Test("A nullable enumeration also allows null among its values")
    func nullableEnumeration() throws {
        #expect(
            try json(.enumeration(["admin", "user"]).nullable())
                == #"{"enum":["admin","user",null],"type":["string","null"]}"#
        )
    }

    @Test("Making an enumeration nullable twice adds null only once")
    func nullableEnumerationIsIdempotent() throws {
        #expect(try json(.enumeration(["admin"]).nullable().nullable()) == json(.enumeration(["admin"]).nullable()))
    }

    @Test("A single-value enumeration is written as const")
    func singleValueEnumeration() throws {
        #expect(try json(.enumeration(["admin"])) == #"{"const":"admin","type":"string"}"#)
    }

    @Test("An empty enumeration is rejected")
    func emptyEnumerationTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = OpenAPISchema.enumeration([])
        }
    }

    @Test(
        "Containers can be nullable",
        arguments: [
            (OpenAPISchema.array(of: .string()).nullable(), #"{"items":{"type":"string"},"type":["array","null"]}"#),
            (.object().nullable(), #"{"type":["object","null"]}"#),
            (
                .dictionary(of: .integer()).nullable(),
                #"{"additionalProperties":{"type":"integer"},"type":["object","null"]}"#
            ),
        ]
    )
    func nullableContainers(schema: OpenAPISchema, expected: String) throws {
        #expect(try json(schema) == expected)
    }

    @Test("A description keeps an optional property out of the required list")
    func descriptionKeepsOptional() throws {
        let schema = OpenAPISchema.object(["nickname": .string().optional().description("Shown to friends")])
        #expect(
            try json(schema)
                == #"{"properties":{"nickname":{"description":"Shown to friends","type":"string"}},"type":"object"}"#
        )
    }

    @Test("Object properties keep the order they're listed in")
    func propertyOrder() throws {
        let schema = OpenAPISchema.object(["zeta": .string(), "alpha": .string(), "mid": .string()])
        let keys = try #require(schema.schema.objectContext).properties.map(\.key)
        #expect(keys == ["zeta", "alpha", "mid"])
    }

    @Test("Schemas compare by what they describe")
    func equality() {
        #expect(OpenAPISchema.string(format: .uuid) == .string(format: .uuid))
        #expect(OpenAPISchema.string() != .integer())
        #expect(OpenAPISchema.string() != .string().nullable())
        #expect(OpenAPISchema.object(["a": .string()]) != .object(["a": .string().optional()]))
    }

    @Test("An enum with associated values is one of its cases, each keyed by its name")
    func oneOf() throws {
        let schema = OpenAPISchema.one(
            of: .object(["circle": .object(["radius": .number()])]),
            .object(["square": .object(["side": .number()])])
        )
        #expect(
            try json(schema)
                == #"{"oneOf":[{"properties":{"circle":{"properties":{"radius":{"type":"number"}},"required":["radius"],"type":"object"}},"required":["circle"],"type":"object"},{"properties":{"square":{"properties":{"side":{"type":"number"}},"required":["side"],"type":"object"}},"required":["square"],"type":"object"}]}"#
        )
    }

    @Test("Compositions list their schemas in order")
    func compositions() throws {
        #expect(try json(.any(of: .string(), .integer())) == #"{"anyOf":[{"type":"string"},{"type":"integer"}]}"#)
        #expect(
            try json(.all(of: [.string(), .string(format: .uuid)])) == #"{"allOf":[{"type":"string"},{"format":"uuid","type":"string"}]}"#)
        #expect(OpenAPISchema.one(of: .string()) == .one(of: [.string()]))
    }

    @Test("A nullable composition allows null alongside it")
    func nullableComposition() throws {
        #expect(
            try json(.one(of: .string(), .integer()).nullable())
                == #"{"anyOf":[{"oneOf":[{"type":"string"},{"type":"integer"}]},{"type":"null"}]}"#
        )
    }

    @Test("An empty composition is rejected")
    func emptyCompositionsTrap() async {
        await #expect(processExitsWith: .failure) { _ = OpenAPISchema.one(of: []) }
        await #expect(processExitsWith: .failure) { _ = OpenAPISchema.any(of: []) }
        await #expect(processExitsWith: .failure) { _ = OpenAPISchema.all(of: []) }
    }

    @Test("Modifiers return a copy and leave the original untouched")
    func modifiersCopy() throws {
        let original = OpenAPISchema.string()
        _ = original.nullable().description("changed")
        #expect(try json(original) == #"{"type":"string"}"#)
    }
}
#endif
