#if OpenAPI
import HTTPTypes
import OpenAPIKit
import RoutingKit
import Synchronization
import Testing
import Vapor
@testable import VaporOpenAPI
import VaporTesting

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private struct Pet: Content { var name: String }

private struct Measurements: Content {
    var small: Int8?
    var unsigned: UInt16?
    var ratio: Float?
    var price: Double?
    var flag: Bool?
    var counts: [String: Int]?
    var born: Date?
    var site: URL?
    var id: UUID?
}

/// Decodes itself by hand, asking which keys are there and which are null.
private struct HandDecoded: Content {
    var name: String
    var nickname: String?

    enum CodingKeys: String, CodingKey { case name, nickname }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        let hasNickname = container.contains(.nickname)
        nickname = try hasNickname && !container.decodeNil(forKey: .nickname) ? container.decode(String.self, forKey: .nickname) : nil
    }
}

/// Reads its fields from inside a nested object.
private struct Wrapped: Content {
    var name: String

    enum CodingKeys: String, CodingKey { case data }
    enum DataKeys: String, CodingKey { case name }

    init(name: String) { self.name = name }

    init(from decoder: any Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self).nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        name = try data.decode(String.self, forKey: .name)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var data = container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        try data.encode(name, forKey: .name)
    }
}

/// The same, describing its own schema.
private struct DescribedWrapped: Decodable, OpenAPISchemaProvider {
    static var openAPISchema: OpenAPISchema { .object(["data": .object(["name": .string()])]) }

    init(from decoder: any Decoder) throws {
        _ = try decoder.container(keyedBy: Wrapped.CodingKeys.self)
            .nestedContainer(keyedBy: Wrapped.DataKeys.self, forKey: .data)
    }
}

/// Decodes its own field, then its superclass's from the same decoder.
private class Animal: Decodable {
    var id: Int
}

private final class Dog: Animal {
    var breed: String

    enum CodingKeys: String, CodingKey { case breed }

    required init(from decoder: any Decoder) throws {
        breed = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .breed)
        try super.init(from: decoder)
    }
}

/// Decodes another type's fields from its own decoder, then one of its own.
private struct Tagged: Decodable {
    var pet: Pet
    var tag: String

    enum CodingKeys: String, CodingKey { case tag }

    init(from decoder: any Decoder) throws {
        pet = try Pet(from: decoder)
        tag = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .tag)
    }
}

private enum PetID: OpenAPILinkKey {}

/// A JSON-like value: an enum that's also `ExpressibleByNilLiteral`, holding arrays of itself.
private indirect enum JSONValue: Decodable, ExpressibleByNilLiteral {
    case null
    case array([JSONValue])

    init(nilLiteral: ()) { self = .null }

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items: [JSONValue] = []
        while !container.isAtEnd { items.append(try container.decode(JSONValue.self)) }
        self = .array(items)
    }
}

/// Counts how often it's decoded.
private struct Counted: Decodable {
    static let decodes = Atomic(0)
    var name: String

    enum CodingKeys: String, CodingKey { case name }

    init(from decoder: any Decoder) throws {
        Self.decodes.add(1, ordering: .relaxed)
        name = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .name)
    }
}

private struct PetPath: Codable { var petID: Int }

/// The document for the routes `configure` registers, checked by OpenAPIKit's validator.
private func document(_ configure: (Application) throws -> Void) async throws -> OpenAPI.Document {
    try await withApp { app in
        try configure(app)
        let document = try app.routes.openAPI(info: OpenAPIInfo(title: "Pets", version: "1.0.0")).document
        _ = try document.validate()
        return document
    }
}

/// The JSON of `document`, with sorted keys.
private func json(_ document: OpenAPI.Document) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(document), as: UTF8.self)
}

/// The path parameters' names of the operation at `path` for `method`.
private func pathParameters(_ document: OpenAPI.Document, _ path: String, _ method: OpenAPI.HttpMethod = .get) -> [String] {
    let operation = document.paths[OpenAPI.Path(rawValue: path)]?.pathItemValue?[method]
    return operation?.parameters.compactMap(\.b).filter { $0.location == .path }.map(\.name) ?? []
}

@Suite("Edge cases")
struct EdgeCaseTests {
    // MARK: Paths

    @Test("A wildcard is a parameter named anything, and the next one anything2")
    func wildcards() async throws {
        let document = try await document { app in
            app.get("files", "*") { _ in "x" }
            app.get("a", "*", "b", "*") { _ in "x" }
        }
        #expect(pathParameters(document, "/files/{anything}") == ["anything"])
        #expect(pathParameters(document, "/a/{anything}/b/{anything2}") == ["anything", "anything2"])
    }

    @Test("A wildcard skips the names the route's own parameters use")
    func wildcardNameTaken() async throws {
        let document = try await document { app in
            app.get(":anything", "*") { _ in "x" }
            app.get(":anything2", "*", "*") { _ in "x" }
        }
        #expect(pathParameters(document, "/{anything}/{anything2}") == ["anything", "anything2"])
        #expect(pathParameters(document, "/{anything2}/{anything}/{anything3}") == ["anything2", "anything", "anything3"])
    }

    @Test("A parameter inside a segment keeps its template, and each name is a parameter")
    func partialParameter() async throws {
        let document = try await document { app in
            app.get("users", ":user-{id}-details") { _ in "x" }
            app.get("ranges", ":{from}-{to}") { _ in "x" }
        }
        #expect(pathParameters(document, "/users/user-{id}-details") == ["id"])
        #expect(pathParameters(document, "/ranges/{from}-{to}") == ["from", "to"])
    }

    @Test("A parameter whose name has braces fails")
    func parameterWithBraces() async throws {
        let error = await #expect(throws: OpenAPIDocumentError.self) {
            try await document { app in app.on(.get, [.parameter("a{b}")]) { _ in "x" } }
        }
        #expect(error?.reason.contains(#"the path parameter "a{b}" has braces"#) == true)
    }

    @Test("The root route is the path /")
    func root() async throws {
        let document = try await document { app in app.get { _ in "root" } }
        #expect(document.paths[OpenAPI.Path(rawValue: "/")]?.pathItemValue?.get != nil)
    }

    @Test("Paths that differ only in their parameters' names fail, naming both routes")
    func sameShape() async throws {
        let error = await #expect(throws: OpenAPIDocumentError.self) {
            try await document { app in
                app.get("users", ":id") { _ in "x" }
                app.post("users", ":userID") { _ in "x" }
            }
        }
        #expect(error?.route == "POST /users/:userID")
        #expect(error?.reason.hasPrefix("is the same path to OpenAPI as GET /users/:id") == true)
    }

    @Test("Paths with the same shape in different places are different paths")
    func differentShapes() async throws {
        let document = try await document { app in
            app.get("users", ":id") { _ in "x" }
            app.get(":id", "users") { _ in "x" }
            app.get("users", ":id", "pets") { _ in "x" }
            app.get("users", "user-:id") { _ in "x" }
        }
        #expect(document.paths.count == 4)
    }

    @Test(
        "A path's shape leaves out its parameters' names",
        arguments: [
            ("/users/{id}", "/users/{}"),
            ("/users/user-{id}-details", "/users/user-{}-details"),
            ("/{from}-{to}", "/{}-{}"),
            ("/users", "/users"),
            ("/", "/"),
        ]
    )
    func shape(path: String, shape: String) {
        #expect(OpenAPI.Path(rawValue: path).shape == shape)
    }

    // MARK: Methods

    @Test(
        "Each standard method is its own operation",
        arguments: [
            (HTTPRequest.Method.get, OpenAPI.HttpMethod.get),
            (.put, .put),
            (.post, .post),
            (.delete, .delete),
            (.options, .options),
            (.head, .head),
            (.patch, .patch),
            (.trace, .trace),
            (HTTPRequest.Method("QUERY")!, .query),
        ]
    )
    func standardMethod(method: HTTPRequest.Method, expected: OpenAPI.HttpMethod) {
        #expect(OpenAPI.HttpMethod(method) == expected)
    }

    @Test("A method OpenAPI doesn't name is one of the path's additional operations")
    func customMethod() async throws {
        let document = try await document { app in
            app.on(HTTPRequest.Method("PROPFIND")!, "files") { _ in "x" }
        }
        #expect(try json(document).contains(#""/files":{"additionalOperations":{"PROPFIND":{"#))
    }

    // MARK: Bodies and responses

    @Test("A request body is described for each content type given")
    func requestContentTypes() async throws {
        let document = try await document { app in
            app.openAPI(body: .type(Pet.self), contentTypes: [.urlEncodedForm, .formData]).post("pets") { _ in "x" }
        }
        let content = document.paths["/pets"]?.pathItemValue?.post?.requestBody?.b?.content
        #expect(content?.keys.map(\.rawValue).sorted() == ["application/x-www-form-urlencoded", "multipart/form-data"])
    }

    @Test("A response description replaces the status's reason phrase")
    func responseDescription() async throws {
        let document = try await document { app in
            app.openAPI(responseDescription: "The pet's name").get("name") { _ in "Tom" }
        }
        #expect(try json(document).contains(#""description":"The pet's name""#))
    }

    @Test("Optional fields of every kind are described, and none is required")
    func optionalFields() async throws {
        let document = try await document { app in app.get("measurements") { _ in Measurements() } }
        let json = try json(document)
        #expect(json.contains(#""small":{"format":"int32","maximum":127,"minimum":-128,"type":"integer"}"#))
        #expect(json.contains(#""unsigned":{"format":"int32","maximum":65535,"minimum":0,"type":"integer"}"#))
        #expect(json.contains(#""ratio":{"format":"float","type":"number"}"#))
        #expect(json.contains(#""price":{"format":"double","type":"number"}"#))
        #expect(json.contains(#""flag":{"type":"boolean"}"#))
        #expect(json.contains(#""counts":{"additionalProperties":{"format":"int64","type":"integer"},"type":"object"}"#))
        #expect(json.contains(#""born":{"format":"date-time","type":"string"}"#))
        #expect(json.contains(#""site":{"format":"uri-reference","type":"string"}"#))
        #expect(json.contains(#""id":{"format":"uuid","type":"string"}"#))
        #expect(!json.contains(#""required""#))
    }

    // MARK: Hand-written decoding

    @Test("A hand-written decoder sees every key as present and not null")
    func handDecoded() async throws {
        let document = try await document { app in
            app.openAPI(body: .type(HandDecoded.self)).post("pets") { _ in "x" }
        }
        let json = try json(document)
        // `nickname` is optional, but a decoder that says every key is there can't tell.
        #expect(json.contains(#""required":["name","nickname"]"#))
        #expect(json.contains(#""nickname":{"type":"string"}"#))
    }

    @Test("A described type that decodes a nested container fails, naming the route and the key")
    func nestedContainer() async throws {
        let error = await #expect(throws: OpenAPIDocumentError.self) {
            try await document { app in
                app.openAPI(response: .type(Wrapped.self)).get("wrapped") { _ in Wrapped(name: "Tom") }
            }
        }
        #expect(error?.route == "GET /wrapped")
        #expect(error?.reason.contains("Nested containers aren't supported yet") == true)
    }

    @Test("A handler's type that can't be described is left out, and stores no schema")
    func undescribableHandlerType() async throws {
        let document = try await document { app in app.get("wrapped") { _ in Wrapped(name: "Tom") } }
        let json = try json(document)
        #expect(json.contains(#""/wrapped":{"get":{"responses":{"200":{"description":"OK"}}}}"#))
        #expect(!json.contains("Wrapped"))
    }

    @Test("A type that decodes a nested container can describe its own schema instead")
    func nestedContainerDescribed() async throws {
        let document = try await document { app in
            app.openAPI(response: .type(DescribedWrapped.self)).get("wrapped") { _ in "x" }
        }
        #expect(try json(document).contains(#""data":{"properties":{"name":{"type":"string"}}"#))
    }

    // MARK: Review fixes

    @Test("A subclass's fields and its superclass's are both described")
    func subclassFields() async throws {
        let document = try await document { app in
            app.openAPI(body: .type(Dog.self), response: .type(Tagged.self)).post("dogs") { _ in "x" }
        }
        let json = try json(document)
        #expect(
            json.contains(
                #""Dog":{"properties":{"breed":{"type":"string"},"id":{"format":"int64","type":"integer"}},"required":["breed","id"]"#
            ))
        #expect(json.contains(#""Tagged":{"properties":{"name":{"type":"string"},"tag":{"type":"string"}},"required":["name","tag"]"#))
    }

    @Test("An auth id that can't be a component's name fails, naming the route")
    func invalidAuthID() async throws {
        let error = await #expect(throws: OpenAPIDocumentError.self) {
            try await document { app in app.openAPI(auth: [.bearer(id: "my auth")]).get("a") { _ in "a" } }
        }
        #expect(error?.route == "GET /a")
        #expect(error?.reason.contains(#"its auth id "my auth" isn't a valid component name"#) == true)
    }

    @Test("Schemes that differ only in their descriptions are one scheme, with the first description")
    func schemeDescriptions() async throws {
        let document = try await document { app in
            app.openAPI(auth: [.bearer()]).get("a") { _ in "a" }
            app.openAPI(auth: [.bearer(description: "A JWT")]).get("b") { _ in "b" }
        }
        #expect(document.components.securitySchemes.count == 1)
        #expect(try json(document).contains(#""http_bearer":{"scheme":"bearer","type":"http"}"#))
    }

    @Test("Schemes of one kind with different URLs still need ids of their own")
    func schemeURLs() async throws {
        await #expect(throws: OpenAPIDocumentError.self) {
            try await document { app in
                app.openAPI(auth: [.openIDConnect(url: URL(string: "https://a.example")!)]).get("a") { _ in "a" }
                app.openAPI(auth: [.openIDConnect(url: URL(string: "https://b.example")!)]).get("b") { _ in "b" }
            }
        }
    }

    @Test("A link to an operation with a method OpenAPI doesn't name points into additionalOperations")
    func linkToCustomMethod() async throws {
        let document = try await document { app in
            app.openAPI(response: .type(Pet.self), links: [OpenAPILink("name", in: .response(.body)): PetID.self])
                .post("pets") { _ in "x" }
            app.openAPI(links: [OpenAPILink("name", in: .request(.path)): PetID.self])
                .on(HTTPRequest.Method("PROPFIND")!, "pets", ":name") { _ in "x" }
        }
        #expect(try json(document).contains(##""operationRef":"#/paths/~1pets~1%7Bname%7D/additionalOperations/PROPFIND""##))
    }

    @Test("A type that's also an optional or collection and contains itself fails instead of recursing forever")
    func recursiveWrapper() async throws {
        let error = await #expect(throws: OpenAPIDocumentError.self) {
            try await document { app in app.openAPI(response: .type(JSONValue.self)).get("json") { _ in "x" } }
        }
        #expect(error?.reason.contains("it contains itself, and is a collection or optional itself") == true)
    }

    @Test("A path: parameter the path doesn't have fails, listing the path's")
    func unknownPathParameter() async throws {
        let error = await #expect(throws: OpenAPIDocumentError.self) {
            try await document { app in app.openAPI(path: .type(PetPath.self)).get("pets", ":id") { _ in "x" } }
        }
        #expect(error?.route == "GET /pets/:id")
        #expect(error?.reason.contains(#"describe "petID", which isn't in the path. The path's parameters are "id"."#) == true)
    }

    @Test("A request body without content types of its own is in its type's default, as a response is")
    func requestDefaultContentType() async throws {
        let document = try await document { app in
            app.openAPI(body: .type(String.self), response: .type(String.self)).post("echo") { _ in "x" }
        }
        let operation = document.paths["/echo"]?.pathItemValue?.post
        #expect(operation?.requestBody?.b?.content.keys.map(\.rawValue) == ["text/plain"])
        #expect(operation?.responses[status: 200]?.b?.content.keys.map(\.rawValue) == ["text/plain"])
    }

    @Test("A type used by many routes is decoded once")
    func decodedOnce() async throws {
        let before = Counted.decodes.load(ordering: .relaxed)
        _ = try await document { app in
            for name in ["a", "b", "c"] {
                app.openAPI(response: .type(Counted.self)).get(PathComponent(stringLiteral: name)) { _ in "x" }
            }
        }
        #expect(Counted.decodes.load(ordering: .relaxed) - before == 1)
    }

    // MARK: Info and documentation routes

    @Test("The API's summary and description are in the document's info")
    func info() async throws {
        try await withApp { app in
            let info = OpenAPIInfo(title: "Pets", version: "2.1.0", summary: "Pets for sale", description: "All about pets.")
            let document = try app.routes.openAPI(info: info).document
            #expect(document.info.title == "Pets")
            #expect(document.info.version == "2.1.0")
            #expect(document.info.summary == "Pets for sale")
            #expect(document.info.description == "All about pets.")
        }
    }

    @Test("The application serves the documentation at a path given as an array")
    func applicationArrayPath() async throws {
        try await withApp { app in
            app.openAPIDocumentation(["api", "docs"], info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
            try await app.testing { client in
                let document = try await client.get("/api/docs/openapi.json")
                let page = try await client.get("/api/docs")
                #expect(document.status == .ok)
                #expect(page.status == .ok)
            }
        }
    }
}
#endif
