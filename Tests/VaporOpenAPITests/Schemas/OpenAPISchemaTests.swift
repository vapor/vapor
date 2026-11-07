#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

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
        "Formats encode as their JSON Schema names",
        arguments: [
            (OpenAPISchema.string(format: .date), "string", "date"),
            (.string(format: .dateTime), "string", "date-time"),
            (.string(format: .time), "string", "time"),
            (.string(format: .duration), "string", "duration"),
            (.string(format: .email), "string", "email"),
            (.string(format: .idnEmail), "string", "idn-email"),
            (.string(format: .hostname), "string", "hostname"),
            (.string(format: .idnHostname), "string", "idn-hostname"),
            (.string(format: .ipv4), "string", "ipv4"),
            (.string(format: .ipv6), "string", "ipv6"),
            (.string(format: .uri), "string", "uri"),
            (.string(format: .uriReference), "string", "uri-reference"),
            (.string(format: .uriTemplate), "string", "uri-template"),
            (.string(format: .iri), "string", "iri"),
            (.string(format: .iriReference), "string", "iri-reference"),
            (.string(format: .uuid), "string", "uuid"),
            (.string(format: .jsonPointer), "string", "json-pointer"),
            (.string(format: .relativeJsonPointer), "string", "relative-json-pointer"),
            (.string(format: .regex), "string", "regex"),
            (.string(format: .password), "string", "password"),
            (.string(format: .other("phone")), "string", "phone"),
            (.integer(format: .int32), "integer", "int32"),
            (.integer(format: .int64), "integer", "int64"),
            (.integer(format: .other("uint8")), "integer", "uint8"),
            (.number(format: .float), "number", "float"),
            (.number(format: .double), "number", "double"),
            (.number(format: .other("decimal")), "number", "decimal"),
        ]
    )
    func formats(schema: OpenAPISchema, type: String, name: String) throws {
        #expect(try json(schema) == #"{"format":"\#(name)","type":"\#(type)"}"#)
    }

    @Test("A custom format with no name is no format, and one with a listed name is that format")
    func otherFormats() throws {
        #expect(try json(.string(format: .other(""))) == #"{"type":"string"}"#)
        #expect(try json(.integer(format: .other(""))) == #"{"type":"integer"}"#)
        #expect(try json(.number(format: .other(""))) == #"{"type":"number"}"#)
        #expect(OpenAPISchema.string(format: .other("")) == .string())

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

    @Test("A repeated property name keeps the last schema")
    func duplicateProperty() throws {
        let schema = OpenAPISchema.object(["a": .string(), "a": .integer()])
        #expect(try json(schema) == #"{"properties":{"a":{"type":"integer"}},"required":["a"],"type":"object"}"#)
    }

    @Test("Object properties keep the order they're listed in")
    func propertyOrder() throws {
        let schema = OpenAPISchema.object(["zeta": .string(), "alpha": .string(), "mid": .string()])
        let keys = try #require(schema.schema.objectContext).properties.map(\.key)
        #expect(keys == ["zeta", "alpha", "mid"])
    }

    @Test("A dictionary describes its values as additional properties")
    func dictionary() throws {
        #expect(try json(.dictionary(of: .integer())) == #"{"additionalProperties":{"type":"integer"},"type":"object"}"#)
    }

    @Test("An enumeration is a string limited to its values, in order")
    func enumeration() throws {
        #expect(try json(.enumeration(["b", "a"])) == #"{"enum":["b","a"],"type":"string"}"#)
    }

    @Test("A single-value enumeration is written as const")
    func singleValueEnumeration() throws {
        #expect(try json(.enumeration(["admin"])) == #"{"const":"admin","type":"string"}"#)
    }

    @Test(
        "Compositions list their schemas in order",
        arguments: [
            // An enum with associated values is one of its cases, each keyed by its name.
            (
                OpenAPISchema.one(
                    of: .object(["circle": .object(["radius": .number()])]),
                    .object(["square": .object(["side": .number()])])
                ),
                #"{"oneOf":[{"properties":{"circle":{"properties":{"radius":{"type":"number"}},"required":["radius"],"type":"object"}},"required":["circle"],"type":"object"},{"properties":{"square":{"properties":{"side":{"type":"number"}},"required":["side"],"type":"object"}},"required":["square"],"type":"object"}]}"#
            ),
            (.any(of: .string(), .integer()), #"{"anyOf":[{"type":"string"},{"type":"integer"}]}"#),
            (.all(of: [.string(), .string(format: .uuid)]), #"{"allOf":[{"type":"string"},{"format":"uuid","type":"string"}]}"#),
        ]
    )
    func compositions(schema: OpenAPISchema, expected: String) throws {
        #expect(try json(schema) == expected)
    }

    @Test("An empty enumeration or composition is rejected")
    func emptyTraps() async {
        await #expect(processExitsWith: .failure) { _ = OpenAPISchema.enumeration([]) }
        await #expect(processExitsWith: .failure) { _ = OpenAPISchema.one(of: []) }
        await #expect(processExitsWith: .failure) { _ = OpenAPISchema.any(of: []) }
        await #expect(processExitsWith: .failure) { _ = OpenAPISchema.all(of: []) }
    }

    // MARK: - Modifiers

    @Test(
        "Nullable adds null to the type, as in OpenAPI 3.1",
        arguments: [
            (OpenAPISchema.string().nullable(), #"{"type":["string","null"]}"#),
            (.array(of: .string()).nullable(), #"{"items":{"type":"string"},"type":["array","null"]}"#),
            (.object().nullable(), #"{"type":["object","null"]}"#),
            (
                .dictionary(of: .integer()).nullable(),
                #"{"additionalProperties":{"type":"integer"},"type":["object","null"]}"#
            ),
        ]
    )
    func nullable(schema: OpenAPISchema, expected: String) throws {
        #expect(try json(schema) == expected)
    }

    @Test("A nullable enumeration also allows null among its values")
    func nullableEnumeration() throws {
        #expect(
            try json(.enumeration(["admin", "user"]).nullable())
                == #"{"enum":["admin","user",null],"type":["string","null"]}"#
        )
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

    @Test("A description is shown alongside the type, and keeps an optional property out of the required list")
    func description() throws {
        #expect(try json(.string().description("The user's name")) == #"{"description":"The user's name","type":"string"}"#)
        let schema = OpenAPISchema.object(["nickname": .string().optional().description("Shown to friends")])
        #expect(
            try json(schema)
                == #"{"properties":{"nickname":{"description":"Shown to friends","type":"string"}},"type":"object"}"#
        )
    }
}
#endif
