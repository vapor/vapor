#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

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

/// The types an `.allOf` of parameters lists, or `nil` if it isn't one or lists anything else.
private func types(_ parameters: OpenAPIParameters) -> [ObjectIdentifier]? {
    guard case .allOf(let values) = parameters.value else { return nil }
    var types: [ObjectIdentifier] = []
    for value in values {
        guard case .type(let type) = value else { return nil }
        types.append(ObjectIdentifier(type))
    }
    return types
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

private let userAndAudit = ##"[{"$ref":"#/components/schemas/User"},{"$ref":"#/components/schemas/Audit"}]"##

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

    @Test(
        "Each body combination wraps its parts' schemas, in order",
        arguments: [
            (OpenAPIBody.all(of: .type(User.self), .type(Audit.self)), #"{"allOf":\#(userAndAudit)}"#),
            (.any(of: [.type(User.self), .type(Audit.self)]), #"{"anyOf":\#(userAndAudit)}"#),
            // Types and examples can be mixed.
            (.one(of: .type(User.self), .example(Audit(by: "ann"))), #"{"oneOf":\#(userAndAudit)}"#),
            (.not(.type(User.self)), ##"{"not":{"$ref":"#/components/schemas/User"}}"##),
        ]
    )
    func combinations(body: OpenAPIBody, expected: String) throws {
        let result = try schema(body.value)
        #expect(result.schema == expected)
        #expect(result.example == nil)
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

    @Test("An empty body combination is rejected")
    func emptyCombinationsTrap() async {
        await #expect(processExitsWith: .failure) { _ = OpenAPIBody.all(of: [OpenAPIBody]()) }
        await #expect(processExitsWith: .failure) { _ = OpenAPIBody.any(of: [OpenAPIBody]()) }
        await #expect(processExitsWith: .failure) { _ = OpenAPIBody.one(of: [OpenAPIBody]()) }
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

    @Test(
        "Path parameters are always required, while headers and cookies keep the property's optionality",
        arguments: [
            (ParameterLocation.path, #"{"in":"path","name":"search","required":true,"schema":{"type":"string"}}"#),
            (.header, #"{"in":"header","name":"search","schema":{"type":"string"}}"#),
            (.cookie, #"{"in":"cookie","name":"search","schema":{"type":"string"}}"#),
        ]
    )
    func locations(location: ParameterLocation, expected: String) throws {
        #expect(try parameters(.type(Filter.self), in: location).last == expected)
    }

    @Test("An example gives each parameter its own value, and none for a nil property")
    func exampleParameters() throws {
        let result = try parameters(.example(Filter(page: 3, search: nil)))
        #expect(result.first == #"{"example":3,"in":"query","name":"page","required":true,"schema":{"format":"int64","type":"integer"}}"#)
        // The schema still comes from the type, so the nil property is still a parameter.
        #expect(result.last == #"{"in":"query","name":"search","schema":{"type":"string"}}"#)
    }

    @Test("Combined parameters are listed one after another, a later one replacing an earlier one of the same name")
    func combinedParameters() throws {
        let combined: OpenAPIParameters = [.type(Filter.self), .type(Sort.self)]
        #expect(try parameters(combined.value).count == 3)
        #expect(try parameters(combined.value).last == #"{"in":"query","name":"by","required":true,"schema":{"type":"string"}}"#)

        struct Pages: Codable {
            var limit: Int
            var page: Int
        }
        struct Search: Codable {
            var limit: String
            var q: String
        }
        let replaced: OpenAPIParameters = [.type(Pages.self), .type(Search.self)]
        var components = SchemaComponents()
        let list = try replaced.value.parameters(in: .query, into: &components)
        #expect(list.map(\.name) == ["page", "limit", "q"])
        // The later `limit`, a string, not the earlier integer.
        #expect(list[1].schemaOrContent.schemaValue?.jsonType == .string)
    }

    @Test("Combined parameters are flattened into one list, however they're nested or written")
    func flattening() {
        let paging: OpenAPIParameters = [.type(Paging.self)]
        let shallow: OpenAPIParameters = [paging, .all(of: [.type(Filter.self)]), .type(User.self)]
        #expect(types(shallow) == [ObjectIdentifier(Paging.self), ObjectIdentifier(Filter.self), ObjectIdentifier(User.self)])
        let deep = OpenAPIParameters.all(of: .all(of: .all(of: .type(Paging.self))), .type(Filter.self))
        #expect(types(deep) == [ObjectIdentifier(Paging.self), ObjectIdentifier(Filter.self)])
    }

    @Test("An empty list of parameters is allowed, and has no parameters")
    func emptyParameters() throws {
        let literal: OpenAPIParameters = []
        let array = OpenAPIParameters.all(of: [OpenAPIParameters]())
        #expect(types(literal) == [])
        #expect(types(array) == [])
        #expect(try parameters(literal.value).isEmpty)
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
}
#endif
