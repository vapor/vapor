#if OpenAPI
import HTTPTypes
import RoutingKit
import Vapor
import VaporOpenAPI

private enum PetStatus: String, Codable, CaseIterable {
    case available
    case pending
    case sold
}

private struct Pet: Content {
    var id: Int
    var name: String
    var status: PetStatus
}

private struct NewPet: Content {
    var name: String
}

private struct PetFilter: Codable {
    var status: PetStatus?
    var limit: Int?
}

private struct PetPath: Codable {
    var petID: Int
}

private enum PetID: OpenAPILinkKey {
    static var description: String? { "The pet's ID" }
}

/// A small pet store described for OpenAPI, with its document at /docs.
func openAPIExamples(_ app: Application) {
    let pets = app.grouped("openapi", "pets").openAPI(tags: ["Pets"], auth: [.bearer(format: "JWT")])

    pets.openAPI(summary: "List pets", query: .type(PetFilter.self))
        .get { _ in [Pet(id: 1, name: "Tom", status: .available)] }

    // A handler that sets its own status returns a `Response`, so the route describes the body.
    pets.openAPI(
        summary: "Add a pet",
        body: .type(NewPet.self),
        response: .type(Pet.self),
        statusCode: .created,
        links: [OpenAPILink("id", in: .response(.body)): PetID.self]
    )
    .post { req in
        let new = try await req.content.decode(NewPet.self)
        return try await Pet(id: 2, name: new.name, status: .available).encodeResponse(status: .created, for: req)
    }

    pets.openAPI(
        summary: "Get a pet",
        operationID: "getPet",
        path: .type(PetPath.self),
        links: [OpenAPILink("petID", in: .request(.path)): PetID.self]
    )
    .get(":petID") { req in
        Pet(id: try req.parameters.require("petID", as: Int.self), name: "Tom", status: .available)
    }

    app.openAPIDocumentation("docs", info: OpenAPIInfo(title: "Development", version: "1.0.0"))
}
#endif
