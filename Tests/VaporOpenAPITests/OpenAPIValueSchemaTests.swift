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
private func schema(_ value: OpenAPIValue) throws -> (schema: String, example: String?, components: [String]) {
    var components = SchemaComponents()
    let result = try value.schema(into: &components)
    return (try json(result.schema), try result.example.map(json), components.schemas.keys.map(\.rawValue))
}

/// Each parameter as JSON, in order.
private func parameters(_ value: OpenAPIValue, in location: ParameterLocation = .query) throws -> [String] {
    var components = SchemaComponents()
    return try value.parameters(in: location, into: &components).map(json)
}

private struct User: Codable { var id: Int }
private struct Audit: Codable { var by: String }
private struct Filter: Codable {
    var page: Int
    var search: String?
}
private struct Sort: Codable { var by: String }
private struct Scoped: Codable {
    var team: Audit
}
/// Described by hand as an object, so its properties can be parameters too.
private struct Paging: Codable, OpenAPISchemaProvider {
    var limit: Int
    static var openAPISchema: OpenAPISchema { .object(["limit": .integer()]) }
}

@Suite("OpenAPIValue schemas")
struct OpenAPIValueSchemaTests {
    // MARK: - Schemas

    @Test("A type is described by decoding it, with no example")
    func type() throws {
        let result = try schema(.type(User.self))
        #expect(result.schema == ##"{"$ref":"#/components/schemas/User"}"##)
        #expect(result.example == nil)
        #expect(result.components == ["User"])
    }

    @Test("An example gives both a schema and its example")
    func example() throws {
        let result = try schema(.example(User(id: 7)))
        #expect(result.schema == ##"{"$ref":"#/components/schemas/User"}"##)
        #expect(result.example == #"{"id":7}"#)
    }

    @Test("Combinations wrap their parts' schemas in order")
    func combinations() throws {
        let parts: [OpenAPIValue] = [.type(User.self), .type(Audit.self)]
        let refs = ##"[{"$ref":"#/components/schemas/User"},{"$ref":"#/components/schemas/Audit"}]"##
        #expect(try schema(.allOf(parts)).schema == #"{"allOf":\#(refs)}"#)
        #expect(try schema(.anyOf(parts)).schema == #"{"anyOf":\#(refs)}"#)
        #expect(try schema(.oneOf(parts)).schema == #"{"oneOf":\#(refs)}"#)
        #expect(try schema(.not(.type(User.self))).schema == ##"{"not":{"$ref":"#/components/schemas/User"}}"##)
    }

    @Test("Combinations nest, have no example, and store each component once")
    func nestedCombinations() throws {
        let result = try schema(.allOf([.example(User(id: 1)), .oneOf([.type(User.self), .not(.type(Audit.self))])]))
        #expect(
            result.schema
                == ##"{"allOf":[{"$ref":"#/components/schemas/User"},{"oneOf":[{"$ref":"#/components/schemas/User"},{"not":{"$ref":"#/components/schemas/Audit"}}]}]}"##
        )
        #expect(result.example == nil)
        #expect(result.components == ["User", "Audit"])
    }

    @Test("Bodies built through the public API describe the same schema")
    func publicBody() throws {
        let body = OpenAPIBody.one(of: .type(User.self), .example(Audit(by: "ann")))
        #expect(
            try schema(body.value).schema
                == ##"{"oneOf":[{"$ref":"#/components/schemas/User"},{"$ref":"#/components/schemas/Audit"}]}"##
        )
    }

    @Test("A part that can't be described fails the whole value, and stores nothing")
    func failure() {
        enum Plain: String, Decodable { case only }
        var components = SchemaComponents()
        #expect(throws: (any Error).self) {
            try OpenAPIValue.allOf([.type(User.self), .type(Plain.self)]).schema(into: &components)
        }
        // What the parts before the failing one stored is dropped too.
        #expect(components.schemas.isEmpty)
    }

    // MARK: - Parameters

    @Test("Each property is a parameter, and an optional one may be left out")
    func typeParameters() throws {
        #expect(
            try parameters(.type(Filter.self)) == [
                #"{"in":"query","name":"page","required":true,"schema":{"format":"int64","type":"integer"}}"#,
                #"{"in":"query","name":"search","schema":{"type":"string"}}"#,
            ]
        )
    }

    @Test("Path parameters are always required")
    func pathParameters() throws {
        #expect(
            try parameters(.type(Filter.self), in: .path).last
                == #"{"in":"path","name":"search","required":true,"schema":{"type":"string"}}"#
        )
    }

    @Test("Headers and cookies keep the property's optionality")
    func otherLocations() throws {
        #expect(try parameters(.type(Filter.self), in: .header).last == #"{"in":"header","name":"search","schema":{"type":"string"}}"#)
        #expect(try parameters(.type(Filter.self), in: .cookie).last == #"{"in":"cookie","name":"search","schema":{"type":"string"}}"#)
    }

    @Test("An example gives each parameter its own value, and none for a nil property")
    func exampleParameters() throws {
        let result = try parameters(.example(Filter(page: 3, search: nil)))
        #expect(result.first == #"{"example":3,"in":"query","name":"page","required":true,"schema":{"format":"int64","type":"integer"}}"#)
        // The schema still comes from the type, so the nil property is still a parameter.
        #expect(result.last == #"{"in":"query","name":"search","schema":{"type":"string"}}"#)
    }

    @Test("Combined parameters are listed one after another")
    func combinedParameters() throws {
        let combined: OpenAPIParameters = [.type(Filter.self), .type(Sort.self)]
        #expect(try parameters(combined.value).count == 3)
        #expect(try parameters(combined.value).last == #"{"in":"query","name":"by","required":true,"schema":{"type":"string"}}"#)
    }

    @Test("A property that is an object refers to its component")
    func objectProperty() throws {
        #expect(
            try parameters(.type(Scoped.self))
                == [##"{"in":"query","name":"team","required":true,"schema":{"$ref":"#/components/schemas/Audit"}}"##]
        )
    }

    @Test("A provider's object schema gives parameters too")
    func providerParameters() throws {
        #expect(
            try parameters(.type(Paging.self))
                == [#"{"in":"query","name":"limit","required":true,"schema":{"type":"integer"}}"#]
        )
    }

    @Test("Parameters from something other than an object fail and name its type")
    func nonObjectParameters() throws {
        let error = try #require(throws: (any Error).self) { try parameters(.type(Int.self)) }
        #expect("\(error)" == "Parameters must be described by an object, not Int")
        #expect(throws: (any Error).self) { try parameters(.type([Filter].self)) }
    }

    // MARK: - Helpers

    @Test("An example's properties are read by key, and only from an object")
    func exampleProperties() throws {
        var components = SchemaComponents()
        let example = try JSONSchema.example(Filter(page: 2, search: "cat"), into: &components).example
        #expect(try example.properties.map { try $0.mapValues(json) } == ["page": "2", "search": #""cat""#])
        #expect(AnyCodable(5).properties == nil)
    }

    @Test("A reference resolves to its stored component, and anything else to itself")
    func resolved() throws {
        var components = SchemaComponents()
        let reference = try JSONSchema.decoded(User.self, into: &components)
        #expect(
            try json(components.resolved(reference))
                == #"{"properties":{"id":{"format":"int64","type":"integer"}},"required":["id"],"type":"object"}"#)
        #expect(components.resolved(.string) == .string)
        #expect(components.resolved(.reference(.component(named: "Missing"))) == .reference(.component(named: "Missing")))
    }
}
#endif
