#if OpenAPI
import HTTPTypes
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

private enum Status: String, Codable, CaseIterable, OpenAPISchemaProvider {
    case available
    case pending
    case sold
}

private struct Pet: Content {
    var id: Int
    var name: String
    var tag: String?
    var status: Status
}

private struct NewPet: Content {
    var name: String
    var tag: String?
}

private struct PetFilter: Codable {
    var status: Status?
    var limit: Int?
}

private struct PetPath: Codable { var petID: Int }

private struct RequestID: Codable {
    var xRequestID: String

    enum CodingKeys: String, CodingKey {
        case xRequestID = "X-Request-ID"
    }
}

private struct Problem: Content {
    var error: Bool
    var reason: String
}

private enum PetID: OpenAPILinkKey {
    static var description: String? { "The pet's ID" }
}

/// A small pet store, using most of what a route can describe.
private func petstore(_ app: Application) {
    let pets = app.grouped("pets").openAPI(tags: ["Pets"], auth: [.bearer(format: "JWT")])

    pets.openAPI(
        summary: "List pets",
        operationID: "listPets",
        query: .type(PetFilter.self),
        response: .type([Pet].self),
        responseHeaders: .type(RequestID.self)
    )
    .get { _ in [Pet]() }

    pets.openAPI(
        summary: "Add a pet",
        operationID: "addPet",
        body: .type(NewPet.self),
        statusCode: .created,
        links: [OpenAPILink("id", in: .response(.body)): PetID.self]
    )
    .post { _ in Pet(id: 1, name: "Tom", status: .available) }

    pets.openAPI(
        summary: "Get a pet",
        operationID: "getPet",
        path: .type(PetPath.self),
        links: [OpenAPILink("petID", in: .request(.path)): PetID.self]
    )
    .get(":petID") { _ in Pet(id: 1, name: "Tom", status: .available) }

    pets.openAPI(
        summary: "Remove a pet",
        operationID: "deletePet",
        path: .type(PetPath.self),
        // The handler's status is a value, not a type, so it's described here.
        statusCode: .noContent,
        auth: [.bearer(format: "JWT").scopes("admin")],
        deprecated: true
    )
    .delete(":petID") { _ in HTTPResponse.Status.noContent }

    app.openAPI(summary: "Service name", operationID: "name").get("name") { _ in "Petstore" }
    app.openAPI(response: .example(Problem(error: true, reason: "Slow down")), statusCode: .tooManyRequests)
        .get("busy") { _ in Problem(error: true, reason: "Slow down") }
    app.hiddenFromOpenAPI().get("health") { _ in HTTPResponse.Status.ok }
    app.openAPIDocumentation("docs", info: OpenAPIInfo(title: "Petstore", version: "1.0.0"))
}

/// The Petstore document as pretty JSON with sorted keys.
private func documentJSON() async throws -> String {
    try await withApp { app in
        petstore(app)
        let document = try app.routes.openAPI(
            info: OpenAPIInfo(title: "Petstore", version: "1.0.0", summary: "Pets for sale")
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        return String(decoding: try encoder.encode(document), as: UTF8.self)
    }
}

@Suite("Petstore golden document")
struct PetstoreGoldenTests {
    @Test("The document is exactly the one recorded")
    func golden() async throws {
        let json = try await documentJSON()
        #expect(json == recordedDocument)
    }

    @Test("The document is valid OpenAPI")
    func valid() async throws {
        try await withApp { app in
            petstore(app)
            let document = try app.routes.openAPI(info: OpenAPIInfo(title: "Petstore", version: "1.0.0"))
            let warnings = try document.document.validate()
            #expect(warnings.isEmpty, "\(warnings)")
        }
    }

    @Test("OpenAPIKit reads the JSON back as a valid document with the same operations")
    func readBack() async throws {
        let json = try await documentJSON()
        // Not compared as text: OpenAPIKit rebuilds `required` in no fixed order when decoding.
        let decoded = try JSONDecoder().decode(OpenAPI.Document.self, from: Data(json.utf8))
        #expect(try decoded.validate().isEmpty)
        let operationIDs = decoded.allOperationIds.sorted()
        #expect(operationIDs == ["addPet", "deletePet", "getPet", "listPets", "name"])
    }

    @Test("Every route but the hidden ones becomes an operation")
    func everyRoute() async throws {
        try await withApp { app in
            petstore(app)
            let document = try app.routes.openAPI(info: OpenAPIInfo(title: "Petstore", version: "1.0.0"))
            let operations = document.document.paths.values.compactMap(\.pathItemValue).flatMap(\.endpoints)
            // All but /health, /docs and /docs/openapi.json.
            #expect(operations.count == app.routes.all.count - 3)
        }
    }
}

/// Recorded from `documentJSON()`. When the output changes on purpose, check the difference and
/// record it again.
private let recordedDocument = """
    {
      "components" : {
        "links" : {
          "ResponseBodyIdGetPetRequestPathPetID" : {
            "description" : "The pet's ID",
            "operationId" : "getPet",
            "parameters" : {
              "path.petID" : "$response.body#/id"
            }
          }
        },
        "schemas" : {
          "NewPet" : {
            "properties" : {
              "name" : {
                "type" : "string"
              },
              "tag" : {
                "type" : "string"
              }
            },
            "required" : [
              "name"
            ],
            "type" : "object"
          },
          "Pet" : {
            "properties" : {
              "id" : {
                "format" : "int64",
                "type" : "integer"
              },
              "name" : {
                "type" : "string"
              },
              "status" : {
                "$ref" : "#/components/schemas/Status"
              },
              "tag" : {
                "type" : "string"
              }
            },
            "required" : [
              "id",
              "name",
              "status"
            ],
            "type" : "object"
          },
          "Problem" : {
            "properties" : {
              "error" : {
                "type" : "boolean"
              },
              "reason" : {
                "type" : "string"
              }
            },
            "required" : [
              "error",
              "reason"
            ],
            "type" : "object"
          },
          "Status" : {
            "enum" : [
              "available",
              "pending",
              "sold"
            ],
            "type" : "string"
          }
        },
        "securitySchemes" : {
          "http_bearer_JWT" : {
            "bearerFormat" : "JWT",
            "scheme" : "bearer",
            "type" : "http"
          }
        }
      },
      "info" : {
        "summary" : "Pets for sale",
        "title" : "Petstore",
        "version" : "1.0.0"
      },
      "openapi" : "3.2.1",
      "paths" : {
        "/busy" : {
          "get" : {
            "responses" : {
              "429" : {
                "content" : {
                  "application/json" : {
                    "example" : {
                      "error" : true,
                      "reason" : "Slow down"
                    },
                    "schema" : {
                      "$ref" : "#/components/schemas/Problem"
                    }
                  }
                },
                "description" : "Too Many Requests"
              }
            }
          }
        },
        "/name" : {
          "get" : {
            "operationId" : "name",
            "responses" : {
              "200" : {
                "content" : {
                  "text/plain" : {
                    "schema" : {
                      "type" : "string"
                    }
                  }
                },
                "description" : "OK"
              }
            },
            "summary" : "Service name"
          }
        },
        "/pets" : {
          "get" : {
            "operationId" : "listPets",
            "parameters" : [
              {
                "in" : "query",
                "name" : "status",
                "schema" : {
                  "$ref" : "#/components/schemas/Status"
                }
              },
              {
                "in" : "query",
                "name" : "limit",
                "schema" : {
                  "format" : "int64",
                  "type" : "integer"
                }
              }
            ],
            "responses" : {
              "200" : {
                "content" : {
                  "application/json" : {
                    "schema" : {
                      "items" : {
                        "$ref" : "#/components/schemas/Pet"
                      },
                      "type" : "array"
                    }
                  }
                },
                "description" : "OK",
                "headers" : {
                  "X-Request-ID" : {
                    "required" : true,
                    "schema" : {
                      "type" : "string"
                    }
                  }
                }
              }
            },
            "security" : [
              {
                "http_bearer_JWT" : [

                ]
              }
            ],
            "summary" : "List pets",
            "tags" : [
              "Pets"
            ]
          },
          "post" : {
            "operationId" : "addPet",
            "requestBody" : {
              "content" : {
                "application/json" : {
                  "schema" : {
                    "$ref" : "#/components/schemas/NewPet"
                  }
                }
              },
              "required" : true
            },
            "responses" : {
              "201" : {
                "content" : {
                  "application/json" : {
                    "schema" : {
                      "$ref" : "#/components/schemas/Pet"
                    }
                  }
                },
                "description" : "Created",
                "links" : {
                  "ResponseBodyIdGetPetRequestPathPetID" : {
                    "$ref" : "#/components/links/ResponseBodyIdGetPetRequestPathPetID"
                  }
                }
              }
            },
            "security" : [
              {
                "http_bearer_JWT" : [

                ]
              }
            ],
            "summary" : "Add a pet",
            "tags" : [
              "Pets"
            ]
          }
        },
        "/pets/{petID}" : {
          "delete" : {
            "deprecated" : true,
            "operationId" : "deletePet",
            "parameters" : [
              {
                "in" : "path",
                "name" : "petID",
                "required" : true,
                "schema" : {
                  "format" : "int64",
                  "type" : "integer"
                }
              }
            ],
            "responses" : {
              "204" : {
                "description" : "No Content"
              }
            },
            "security" : [
              {
                "http_bearer_JWT" : [
                  "admin"
                ]
              }
            ],
            "summary" : "Remove a pet",
            "tags" : [
              "Pets"
            ]
          },
          "get" : {
            "operationId" : "getPet",
            "parameters" : [
              {
                "in" : "path",
                "name" : "petID",
                "required" : true,
                "schema" : {
                  "format" : "int64",
                  "type" : "integer"
                }
              }
            ],
            "responses" : {
              "200" : {
                "content" : {
                  "application/json" : {
                    "schema" : {
                      "$ref" : "#/components/schemas/Pet"
                    }
                  }
                },
                "description" : "OK"
              }
            },
            "security" : [
              {
                "http_bearer_JWT" : [

                ]
              }
            ],
            "summary" : "Get a pet",
            "tags" : [
              "Pets"
            ]
          }
        }
      },
      "tags" : [
        {
          "name" : "Pets"
        }
      ]
    }
    """
#endif
