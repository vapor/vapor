#if OpenAPI
import Testing
import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// No `@testable` here: this file only sees the public API, so it fails to compile if anything a
// user needs is accidentally internal.

private enum CustomerID: OpenAPILinkKey {}
private enum InvoiceID: OpenAPILinkKey {
    static var description: String? { "The invoice to fetch" }
}

@Suite("Public API")
struct PublicAPITests {
    @Test("A link key can be declared outside the module, with or without a description")
    func linkKeys() {
        #expect(CustomerID.description == nil)
        #expect(InvoiceID.description == "The invoice to fetch")
    }

    @Test("Links can be built and changed outside the module")
    func links() {
        var link = OpenAPILink("id", in: .response(.body))
        #expect(link.name == "id")
        #expect(link.location.description == "response.body")

        link.name = "session"
        link.location = .request(.cookie)
        #expect(link == OpenAPILink("session", in: .request(.cookie)))
    }

    @Test("Auth schemes and OAuth2 flows can be built outside the module")
    func auth() throws {
        let authURL = try #require(URL(string: "https://example.com/authorize"))
        let tokenURL = try #require(URL(string: "https://example.com/token"))
        let auths: [OpenAPIAuth] = [
            .basic(id: "basic", description: "Basic"),
            .bearer(format: "JWT"),
            .apiKey(name: "X-API-Key", in: .query),
            .openIDConnect(url: authURL),
            .oauth2(flows: .implicit(authorizationUrl: authURL, refreshUrl: tokenURL, scopes: ["read": "Read"])),
            .oauth2(flows: .password(tokenUrl: tokenURL)),
            .oauth2(flows: .clientCredentials(tokenUrl: tokenURL, scopes: ["read": "Read"])),
            .oauth2(flows: .authorizationCode(authorizationUrl: authURL, tokenUrl: tokenURL), metadataUrl: authURL),
            .oauth2(flows: .deviceAuthorization(deviceAuthorizationUrl: authURL, tokenUrl: tokenURL)),
            .mutualTLS(),
        ]
        #expect(auths.map { $0.scopes("read").scopes } == Array(repeating: ["read"], count: auths.count))
        #expect(auths.map { $0.scopes(["a", "b"]).scopes } == Array(repeating: ["a", "b"], count: auths.count))
        #expect(auths.allSatisfy { !$0.id.isEmpty })
    }

    // These only need to compile: the structure they build is checked in `OpenAPIValueSchemaTests`.

    @Test("Bodies can be built outside the module, from variadics or arrays")
    func bodies() {
        let variants: [OpenAPIBody] = [.type(PublicUser.self), .example(PublicUser(id: 1))]
        _ = OpenAPIBody.type(PublicModel.self)
        _ = OpenAPIBody.all(of: .type(PublicUser.self), .example(PublicUser(id: 2)))
        _ = OpenAPIBody.any(of: .type(PublicUser.self))
        _ = OpenAPIBody.one(of: .type(PublicUser.self), .not(.type(PublicUser.self)))
        _ = OpenAPIBody.all(of: variants)
        _ = OpenAPIBody.any(of: variants)
        _ = OpenAPIBody.one(of: variants)
    }

    @Test("Parameters can be built outside the module, from variadics, arrays or literals")
    func parameters() {
        let common: [OpenAPIParameters] = [.type(PublicUser.self)]
        let literal: OpenAPIParameters = [.type(PublicUser.self), .example(PublicUser(id: 3))]
        _ = OpenAPIParameters.type(PublicModel.self)
        _ = OpenAPIParameters.example(PublicUser(id: 1))
        _ = OpenAPIParameters.all(of: .type(PublicUser.self), literal)
        _ = OpenAPIParameters.all(of: common + [literal])
    }
}

extension PublicAPITests {
    @Test("Schemas can be built and refined outside the module")
    func schemas() {
        _ = OpenAPISchema.object([
            "id": .string(format: .uuid),
            "phone": .string(format: .other("phone")).optional(),
            "count": .integer(format: .int64),
            "ratio": .number(format: .double).optional(),
            "active": .boolean,
            "tags": .array(of: .string()),
            "scores": .dictionary(of: .integer(format: .other("uint8"))),
            "role": .enumeration(["admin", "user"]).description("The user's role"),
        ])
    }

    @Test("Types outside the module can describe their own schema, or take the enum default")
    func schemaProviders() {
        #expect(PublicRole.openAPISchema == .enumeration(["admin", "user"]))
        #expect(PublicMoney.openAPISchema == .string(format: .other("money")))
    }
}

private enum PublicRole: String, CaseIterable, OpenAPISchemaProvider {
    case admin
    case user
}

private struct PublicMoney: OpenAPISchemaProvider {
    static var openAPISchema: OpenAPISchema { .string(format: .other("money")) }
}

private struct PublicUser: Codable, Sendable {
    var id: Int
}

/// Not `Sendable`: describing it by type only needs its metatype.
private final class PublicModel: Decodable {
    var id = 0
}
#endif
