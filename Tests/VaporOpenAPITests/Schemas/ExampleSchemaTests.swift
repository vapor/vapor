#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private func json(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
}

/// The schema and example for `value`, as JSON, and the names of the components it stored.
private func example(_ value: some Encodable) throws -> (schema: String, example: String, components: [String]) {
    var components = SchemaComponents()
    let result = try JSONSchema.example(value, into: &components)
    return (try json(result.schema), try json(result.example), components.schemas.keys.map(\.rawValue))
}

private struct User: Codable {
    var id: Int
    var name: String
}
private struct Report: Encodable { var title: String }
/// Only `Encodable`, but describes itself.
private struct Money: Encodable, OpenAPISchemaProvider {
    var amount: String
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(amount)
    }
    static var openAPISchema: OpenAPISchema { .string() }
}

@Suite("Example schemas")
struct ExampleSchemaTests {
    @Test("An object's example is its JSON, next to a reference to its component")
    func object() throws {
        let result = try example(User(id: 1, name: "Ann"))
        #expect(result.schema == ##"{"$ref":"#/components/schemas/User"}"##)
        #expect(result.example == #"{"id":1,"name":"Ann"}"#)
        #expect(result.components == ["User"])
    }

    @Test("Dates are encoded as ISO 8601, matching their date-time schema")
    func date() throws {
        let result = try example(Date(timeIntervalSince1970: 0))
        #expect(result.schema == #"{"format":"date-time","type":"string"}"#)
        #expect(result.example == #""1970-01-01T00:00:00Z""#)
        #expect(result.components.isEmpty)
    }

    @Test("Arrays stay inline")
    func array() throws {
        let result = try example([1, 2])
        #expect(result.schema == #"{"items":{"format":"int64","type":"integer"},"type":"array"}"#)
        #expect(result.example == "[1,2]")
    }

    @Test("A provider needn't be Decodable")
    func encodableProvider() throws {
        let result = try example(Money(amount: "9.99"))
        #expect(result.schema == #"{"type":"string"}"#)
        #expect(result.example == #""9.99""#)
    }

    @Test("A type that is only Encodable names itself and suggests a fix")
    func encodableOnly() throws {
        var components = SchemaComponents()
        let error = try #require(throws: (any Error).self) {
            try JSONSchema.example(Report(title: "Q3"), into: &components)
        }
        #expect("\(error)".hasPrefix("Report is only Encodable"))
        // The protocol to adopt, not the schema value it returns.
        #expect("\(error)".hasSuffix("describe it with OpenAPISchemaProvider"))
        #expect(components.schemas.isEmpty)
    }

    // MARK: - Edge cases

    @Test("A nil example is null, next to a schema that allows null")
    func nilValue() throws {
        let result = try example(Int?.none)
        #expect(result.schema == #"{"format":"int64","type":["integer","null"]}"#)
        #expect(result.example == "null")
    }

    @Test("Dates inside an object are encoded as ISO 8601 too")
    func nestedDate() throws {
        let result = try example(Stamped(at: Date(timeIntervalSince1970: 0)))
        #expect(result.example == #"{"at":"1970-01-01T00:00:00Z"}"#)
    }

    @Test("Data is base64, matching its schema")
    func data() throws {
        let result = try example(Data([1, 2, 3]))
        #expect(result.schema == #"{"contentEncoding":"base64","type":"string"}"#)
        #expect(result.example == #""AQID""#)
    }

    @Test("A value JSON can't hold is an error, and stores nothing")
    func unencodable() {
        var components = SchemaComponents()
        #expect(throws: EncodingError.self) { try JSONSchema.example(Measured(value: .nan), into: &components) }
        #expect(components.schemas.isEmpty)
    }

    // Unsigned values above Int64.max aren't checked: on Apple platforms OpenAPIKit's AnyCodable
    // encodes them through NSNumber, which turns UInt64.max into -1.
    @Test("The largest signed 64-bit integer keeps its value")
    func largeIntegers() throws {
        #expect(try example(Int64.max).example == "9223372036854775807")
        #expect(try example(Int64.min).example == "-9223372036854775808")
    }
}

private struct Stamped: Codable { var at: Date }
private struct Measured: Codable { var value: Double }
#endif
