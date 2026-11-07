#if OpenAPI
import HTTPTypes
import InMemoryLogging
import Logging
import OpenAPIKit
import RoutingKit
import Testing
import Vapor
@testable import VaporOpenAPI
import VaporTesting

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private struct Pet: Codable {
    var id: Int
    var name: String
}
private struct Paging: Codable { var page: Int? }
private enum PetID: OpenAPILinkKey {
    static var description: String? { "The new pet's ID" }
}
private enum Unused: OpenAPILinkKey {}
private struct Identified: Codable { var id: String }
private struct Owner: Codable { var name: String }
private struct Cat: Content { var name: String }
private struct Toy: Codable {
    var name: String
    var owner: Owner
}

/// The document for the routes `configure` registers, as JSON with sorted keys.
private func document(_ configure: (Application) throws -> Void) async throws -> String {
    try await withApp { app in
        try configure(app)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let document = try app.routes.openAPI(info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
        return String(decoding: try encoder.encode(document), as: UTF8.self)
    }
}

@Suite("Routes OpenAPI document")
struct RoutesOpenAPITests {
    @Test("A described route becomes an operation under its path")
    func operation() async throws {
        let json = try await document { app in
            app.openAPI(tags: ["Pets"], summary: "Get a pet", operationID: "getPet", response: .type(Pet.self))
                .get("pets", ":id") { _ in "pet" }
        }
        #expect(json.contains(#""openapi":"3.2.1""#))
        #expect(json.contains(#""info":{"title":"Pets","version":"1.0.0"}"#))
        #expect(json.contains(#""/pets/{id}":{"get":{"#))
        #expect(json.contains(#""operationId":"getPet""#))
        #expect(json.contains(#"{"in":"path","name":"id","required":true,"schema":{"type":"string"}}"#))
        #expect(
            json.contains(##""200":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/Pet"}}},"description":"OK"}"##))
        #expect(json.contains(#""components":{"schemas":{"Pet":"#))
        #expect(json.contains(#""tags":[{"name":"Pets"}]"#))
    }

    @Test("Routes on the same path share it, one operation per method")
    func samePath() async throws {
        let json = try await document { app in
            app.get("pets") { _ in "list" }
            app.openAPI(body: .type(Pet.self), statusCode: .created).post("pets") { _ in "created" }
        }
        #expect(json.contains(#""/pets":{"get":"#))
        #expect(json.contains(#""post":{"#))
        #expect(json.contains(#""201":{"content":{"text/plain":{"schema":{"type":"string"}}},"description":"Created"}"#))
        #expect(
            json.contains(
                ##""requestBody":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/Pet"}}},"required":true}"##))
    }

    @Test("Hidden routes are left out")
    func hidden() async throws {
        let json = try await document { app in
            app.hiddenFromOpenAPI().get("health") { _ in "ok" }
            app.get("pets") { _ in "list" }
        }
        #expect(!json.contains("/health"))
        #expect(json.contains("/pets"))
    }

    @Test("Auth adds a security requirement and its scheme")
    func auth() async throws {
        let json = try await document { app in
            app.openAPI(auth: [.bearer()]).get("me") { _ in "me" }
        }
        #expect(json.contains(#""security":[{"http_bearer":[]}]"#))
        #expect(json.contains(#""securitySchemes":{"http_bearer":{"scheme":"bearer","type":"http"}}"#))
    }

    @Test("Query parameters come from the type")
    func query() async throws {
        let json = try await document { app in
            app.openAPI(query: .type(Paging.self)).get("pets") { _ in "list" }
        }
        #expect(json.contains(#"{"in":"query","name":"page","schema":{"format":"int64","type":"integer"}}"#))
    }

    @Test("A catch-all route is left out, and the other routes are described")
    func catchall() async throws {
        let json = try await document { app in
            app.get("proxy", "**") { _ in "x" }
            app.get("pets") { _ in "pets" }
        }
        #expect(json.contains(#""/pets":{"get":"#))
        #expect(!json.contains("proxy"))
    }

    @Test("A route left out is named in a warning, with why")
    func leftOutWarning() async throws {
        let logHandler = InMemoryLogHandler()
        let logger = Logger(label: "codes.vapor.test", factory: { _ in logHandler })
        try await withApp(logger: logger) { app in
            app.get("proxy", "**") { _ in "x" }
            _ = try app.routes.openAPI(info: OpenAPIInfo(title: "Pets", version: "1.0.0"))
        }
        let warnings = logHandler.entries.filter { $0.level == .warning }.map { "\($0.message)" }
        #expect(
            warnings == [
                "GET /proxy/** is left out of the OpenAPI document: a catch-all path (**) can't be described in OpenAPI. Hide the route with hiddenFromOpenAPI()."
            ])
    }

    @Test("A response value links to a request value with the same key")
    func link() async throws {
        let json = try await document { app in
            app.openAPI(response: .type(Pet.self), links: [OpenAPILink("id", in: .response(.body)): PetID.self])
                .post("pets") { _ in "created" }
            app.openAPI(operationID: "getPet", links: [OpenAPILink("id", in: .request(.path)): PetID.self])
                .get("pets", ":id") { _ in "pet" }
        }
        #expect(
            json.contains(
                ##""links":{"ResponseBodyIdGetPetRequestPathId":{"description":"The new pet's ID","operationId":"getPet","parameters":{"path.id":"$response.body#/id"}}}"##
            )
        )
        #expect(
            json.contains(
                ##""links":{"ResponseBodyIdGetPetRequestPathId":{"$ref":"#/components/links/ResponseBodyIdGetPetRequestPathId"}}"##
            )
        )
    }

    @Test("A target without an operation ID is reached by a pointer to it")
    func linkByReference() async throws {
        let json = try await document { app in
            app.openAPI(links: [OpenAPILink("id", in: .response(.body)): PetID.self]).post("pets") { _ in "created" }
            app.openAPI(links: [OpenAPILink("id", in: .request(.path)): PetID.self]).get("pets", ":id") { _ in "pet" }
        }
        #expect(json.contains(##""operationRef":"#/paths/~1pets~1%7Bid%7D/get""##))
        #expect(json.contains(#""ResponseBodyIdGetPetsByIdRequestPathId""#))
    }

    @Test("A key with no source or no target makes no link")
    func unmatchedLink() async throws {
        let json = try await document { app in
            app.openAPI(links: [OpenAPILink("id", in: .response(.body)): Unused.self]).post("pets") { _ in "created" }
        }
        #expect(!json.contains("links"))
    }

    @Test("A link into a field of a request body fails")
    func linkIntoBodyField() async throws {
        let error = await #expect(throws: (any Error).self) {
            try await document { app in
                app.openAPI(links: [OpenAPILink("id", in: .response(.body)): PetID.self]).post("pets") { _ in "a" }
                app.openAPI(links: [OpenAPILink("owner/id", in: .request(.body)): PetID.self]).put("pets") { _ in "b" }
            }
        }
        #expect("\(error!)".hasPrefix("PUT /pets: a link can only set a whole request body"))
    }

    @Test("Links come out in the order their routes and ends are declared, sorted within a route")
    func stableLinkOrder() async throws {
        let configure: (Application) throws -> Void = { app in
            app.openAPI(links: [
                OpenAPILink("id", in: .response(.body)): PetID.self,
                OpenAPILink("Location", in: .response(.header)): PetID.self,
                OpenAPILink("owner", in: .response(.body)): Unused.self,
            ]).post("pets") { _ in "a" }
            app.openAPI(operationID: "a", links: [OpenAPILink("id", in: .request(.path)): PetID.self]).get("a", ":id") { _ in "a" }
            app.openAPI(operationID: "b", query: .type(Identified.self), links: [OpenAPILink("id", in: .request(.query)): PetID.self]).get(
                "b"
            ) { _ in "b" }
            app.openAPI(operationID: "c", headers: .type(Identified.self), links: [OpenAPILink("id", in: .request(.header)): PetID.self])
                .get("c") { _ in "c" }
        }
        // JSONEncoder reorders keys unless they're sorted, so compare the order in the document itself.
        func linkOrder() async throws -> [String] {
            try await withApp { app in
                try configure(app)
                let document = try app.routes.openAPI(info: OpenAPIInfo(title: "Pets", version: "1.0.0")).document
                return document.components.links.keys.map(\.rawValue)
            }
        }
        // An exact order, since a dictionary keeps one order for a whole process, so comparing runs
        // in one test can't tell sorted from unsorted.
        #expect(
            try await linkOrder() == [
                "ResponseBodyIdARequestPathId", "ResponseBodyIdBRequestQueryId", "ResponseBodyIdCRequestHeaderId",
                "ResponseHeaderLocationARequestPathId", "ResponseHeaderLocationBRequestQueryId",
                "ResponseHeaderLocationCRequestHeaderId",
            ]
        )
    }

    @Test("Different links that come out with the same name are both kept")
    func linkNameCollision() async throws {
        let json = try await document { app in
            app.openAPI(links: [OpenAPILink("owner/id", in: .response(.body)): PetID.self]).post("a") { _ in "a" }
            app.openAPI(links: [OpenAPILink("ownerId", in: .response(.body)): PetID.self]).post("b") { _ in "b" }
            app.openAPI(operationID: "getPet", links: [OpenAPILink("id", in: .request(.path)): PetID.self])
                .get("pets", ":id") { _ in "pet" }
        }
        #expect(
            json.contains(
                ##""ResponseBodyOwnerIdGetPetRequestPathId":{"description":"The new pet's ID","operationId":"getPet","parameters":{"path.id":"$response.body#/owner/id"}}"##
            ))
        #expect(
            json.contains(
                ##""ResponseBodyOwnerIdGetPetRequestPathId2":{"description":"The new pet's ID","operationId":"getPet","parameters":{"path.id":"$response.body#/ownerId"}}"##
            ))
    }

    @Test("A link to a parameter its operation doesn't have fails")
    func linkToMissingParameter() async throws {
        let error = await #expect(throws: (any Error).self) {
            try await document { app in
                app.openAPI(links: [OpenAPILink("id", in: .response(.body)): PetID.self]).post("pets") { _ in "a" }
                app.openAPI(links: [OpenAPILink("id", in: .request(.path)): PetID.self]).get("pets", ":petID") { _ in "b" }
            }
        }
        #expect("\(error!)" == #"GET /pets/:petID: a link sets its path parameter "id", which it doesn't have"#)
    }

    @Test("Two routes with one operation ID fail, naming both")
    func duplicateOperationID() async throws {
        let error = await #expect(throws: (any Error).self) {
            try await document { app in
                let pets = app.openAPI(operationID: "pets")
                pets.get("a") { _ in "a" }
                pets.get("b") { _ in "b" }
            }
        }
        #expect("\(error!)" == #"GET /b: its operation ID "pets" is also GET /a's. Set operationID on a single route."#)
    }

    @Test("A path segment with braces that isn't a parameter is left out")
    func bracesInConstant() async throws {
        let json = try await document { app in app.get("files", "file-{name}.zip") { _ in "x" } }
        #expect(!json.contains("files"))
    }

    @Test("A type used only for parameters isn't kept as a schema")
    func unusedSchemasRemoved() async throws {
        let json = try await document { app in
            app.openAPI(query: .type(Paging.self), response: .type(Pet.self)).get("pets") { _ in "list" }
        }
        #expect(json.contains(#""components":{"schemas":{"Pet":"#))
        #expect(!json.contains("Paging"))
    }

    @Test("A type used for parameters and as a body is kept once, under its own name")
    func parametersTypeAlsoBody() async throws {
        let json = try await document { app in
            app.openAPI(query: .type(Pet.self)).get("search") { _ in "list" }
            app.openAPI(body: .type(Pet.self)).post("pets") { _ in "created" }
        }
        #expect(json.contains(##""$ref":"#/components/schemas/Pet""##))
        #expect(json.contains(#""components":{"schemas":{"Pet":"#))
        #expect(!json.contains("Pet2"))
    }

    @Test("A route registered twice fails")
    func duplicateRoute() async throws {
        let error = await #expect(throws: (any Error).self) {
            try await document { app in
                app.get("pets") { _ in "a" }
                app.get("pets") { _ in "b" }
            }
        }
        #expect("\(error!)" == "GET /pets: is registered twice, so only one could be described")
    }

    @Test("Schemas only other schemas refer to are kept")
    func nestedSchemasKept() async throws {
        let json = try await document { app in
            app.openAPI(response: .type(Toy.self)).get("toys") { _ in "toy" }
        }
        #expect(json.contains(#""Owner":{"#))
        #expect(json.contains(#""Toy":{"#))
    }

    @Test("Two different schemes under one ID fail")
    func authCollision() async throws {
        await #expect(throws: (any Error).self) {
            try await document { app in
                app.openAPI(auth: [.bearer(id: "token")]).get("a") { _ in "a" }
                app.openAPI(auth: [.basic(id: "token")]).get("b") { _ in "b" }
            }
        }
    }

    @Test("A handler's return type is the response body, when no response is described")
    func handlerResponse() async throws {
        let json = try await document { app in
            app.get("cats") { _ in Cat(name: "Tom") }
        }
        #expect(
            json.contains(##""200":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/Cat"}}},"description":"OK"}"##))
    }

    @Test("A handler returning a string or a number is sent as plain text")
    func plainTextHandler() async throws {
        let json = try await document { app in
            app.get("name") { _ in "Tom" }
            app.get("count") { _ in 3 }
        }
        #expect(json.contains(#""200":{"content":{"text/plain":{"schema":{"type":"string"}}},"description":"OK"}"#))
        #expect(json.contains(#""200":{"content":{"text/plain":{"schema":{"format":"int64","type":"integer"}}},"description":"OK"}"#))
    }

    @Test("A handler returning a response has no body")
    func responseHandler() async throws {
        let json = try await document { app in
            app.get("raw") { _ in Response(status: .ok) }
        }
        #expect(json.contains(#""200":{"description":"OK"}"#))
    }

    @Test("A described response replaces the handler's return type")
    func describedResponse() async throws {
        let json = try await document { app in
            app.openAPI(response: .type(Pet.self)).get("pet") { _ in "Tom" }
        }
        #expect(
            json.contains(##""200":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/Pet"}}},"description":"OK"}"##))
        #expect(!json.contains("text/plain"))
    }

    @Test("A described string response is sent as plain text, unless content types are given")
    func describedContentTypes() async throws {
        let json = try await document { app in
            app.openAPI(response: .type(String.self)).get("plain") { _ in Response(status: .ok) }
            app.openAPI(response: .example("Tom")).get("example") { _ in Response(status: .ok) }
            app.openAPI(responseContentTypes: [.html]).get("page") { _ in "<p>Tom</p>" }
        }
        #expect(json.contains(#""/plain":{"get":{"responses":{"200":{"content":{"text/plain":"#))
        #expect(json.contains(#""/example":{"get":{"responses":{"200":{"content":{"text/plain":"#))
        #expect(json.contains(#""/page":{"get":{"responses":{"200":{"content":{"text/html":"#))
    }

    @Test("A composition is sent as its parts are, or as JSON when they differ")
    func compositionContentType() async throws {
        let json = try await document { app in
            app.openAPI(response: .one(of: .type(String.self), .example("Tom"))).get("same") { _ in Response(status: .ok) }
            app.openAPI(response: .one(of: .type(String.self), .type(Cat.self))).get("mixed") { _ in Response(status: .ok) }
        }
        #expect(json.contains(#""/same":{"get":{"responses":{"200":{"content":{"text/plain":"#))
        #expect(json.contains(#""/mixed":{"get":{"responses":{"200":{"content":{"application/json":"#))
    }
}
#endif
