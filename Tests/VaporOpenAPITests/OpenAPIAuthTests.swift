#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private let authorizationURL = URL(string: "https://example.com/oauth/authorize")!
private let tokenURL = URL(string: "https://example.com/oauth/token")!
private let refreshURL = URL(string: "https://example.com/oauth/refresh")!
private let openIDURL = URL(string: "https://example.com/.well-known/openid-configuration")!

@Suite("OpenAPIAuth")
struct OpenAPIAuthTests {
    // MARK: - Ids and scopes

    @Test("An explicit id is used as given, even an empty one, without sanitising")
    func explicitID() {
        #expect(OpenAPIAuth.basic(id: "custom").id == "custom")
        #expect(OpenAPIAuth.bearer(id: "").id == "")
        // Checked when the document is built instead, in `EdgeCaseTests.invalidAuthID`.
        #expect(OpenAPIAuth.basic(id: "my auth").id == "my auth")
    }

    @Test("Setting scopes replaces the previous ones with exactly those given, in order and with duplicates")
    func scopes() {
        #expect(OpenAPIAuth.bearer().scopes("read").scopes("write").scopes == ["write"])
        #expect(OpenAPIAuth.bearer().scopes("read").scopes().scopes.isEmpty)
        #expect(OpenAPIAuth.bearer().scopes("write", "read", "write").scopes == ["write", "read", "write"])
    }

    @Test("Every kind of scheme gets a distinct auto id")
    func autoIDsAreDistinct() {
        let ids = [
            OpenAPIAuth.basic(),
            .bearer(),
            .bearer(format: "JWT"),
            .apiKey(name: "key", in: .query),
            .apiKey(name: "key", in: .header),
            .apiKey(name: "key", in: .cookie),
            .openIDConnect(url: openIDURL),
            .oauth2(flows: .implicit(authorizationUrl: authorizationURL)),
            .oauth2(flows: .password(tokenUrl: tokenURL)),
            .oauth2(flows: .clientCredentials(tokenUrl: tokenURL)),
            .oauth2(flows: .authorizationCode(authorizationUrl: authorizationURL, tokenUrl: tokenURL)),
            .oauth2(flows: .deviceAuthorization(deviceAuthorizationUrl: authorizationURL, tokenUrl: tokenURL)),
            .mutualTLS(),
        ].map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    // MARK: - Schemes

    @Test(
        "Each factory builds its scheme, with an auto id from what the scheme is",
        arguments: [
            (OpenAPIAuth.basic(), "http_basic", OpenAPI.SecurityScheme.SecurityType.http(scheme: "basic", bearerFormat: nil)),
            (.bearer(), "http_bearer", .http(scheme: "bearer", bearerFormat: nil)),
            (.bearer(format: "JWT"), "http_bearer_JWT", .http(scheme: "bearer", bearerFormat: "JWT")),
            // An empty format is left out of the auto id.
            (.bearer(format: ""), "http_bearer", .http(scheme: "bearer", bearerFormat: "")),
            (.openIDConnect(url: openIDURL), "openIdConnect", .openIdConnect(openIdConnectUrl: openIDURL)),
            (.mutualTLS(), "mutualTLS", .mutualTLS),
        ]
    )
    func factories(auth: OpenAPIAuth, id: String, type: OpenAPI.SecurityScheme.SecurityType) {
        #expect(auth.id == id)
        #expect(auth.scheme.type == type)
        #expect(auth.scheme.deprecated == false)
    }

    @Test(
        "API key maps every location",
        arguments: [
            (OpenAPIAuth.SecurityLocation.query, OpenAPI.SecurityScheme.Location.query, "apiKey_query_token"),
            (.header, .header, "apiKey_header_token"),
            (.cookie, .cookie, "apiKey_cookie_token"),
        ]
    )
    func apiKeyLocations(
        location: OpenAPIAuth.SecurityLocation,
        expected: OpenAPI.SecurityScheme.Location,
        id: String
    ) {
        let auth = OpenAPIAuth.apiKey(name: "token", in: location)

        #expect(location.location == expected)
        #expect(auth.id == id)
        #expect(auth.scheme.type == .apiKey(name: "token", location: expected))
    }

    @Test("API keys with different names in the same location get different auto ids")
    func apiKeyNamesDontCollide() {
        let tenant = OpenAPIAuth.apiKey(name: "X-Tenant-Key")
        let api = OpenAPIAuth.apiKey(name: "X-API-Key")

        #expect(tenant.id == "apiKey_header_X-Tenant-Key")
        #expect(tenant.id != api.id)
    }

    // MARK: - Component key safety

    @Test(
        "Characters not allowed in component keys are replaced with a dash",
        arguments: [
            (OpenAPIAuth.bearer(format: "JWT token"), "http_bearer_JWT-token"),
            (OpenAPIAuth.apiKey(name: "X Api Key"), "apiKey_header_X-Api-Key"),
            (OpenAPIAuth.apiKey(name: "key/with:odd@chars"), "apiKey_header_key-with-odd-chars"),
            (OpenAPIAuth.apiKey(name: "ключ"), "apiKey_header_----"),
            (OpenAPIAuth.apiKey(name: "api.key_v2-final"), "apiKey_header_api.key_v2-final"),
        ]
    )
    func autoIDIsComponentKeySafe(auth: OpenAPIAuth, id: String) throws {
        #expect(auth.id == id)
        let allowed = try Regex(#"^[a-zA-Z0-9\.\-_]+$"#)
        #expect(auth.id.wholeMatch(of: allowed) != nil)
    }

    @Test("The scheme itself keeps the original, unsanitised values")
    func sanitisingOnlyAffectsTheID() {
        let auth = OpenAPIAuth.apiKey(name: "X Api Key")
        #expect(auth.scheme.type == .apiKey(name: "X Api Key", location: .header))
    }

    // MARK: - OAuth2

    @Test(
        "Each OAuth2 flow keeps its URLs and scopes, and no other flow is set",
        arguments: [
            (
                OpenAPIAuth.OAuth2Flow.implicit(
                    authorizationUrl: authorizationURL,
                    refreshUrl: refreshURL,
                    scopes: ["read:pets": "Read your pets"]
                ),
                "oauth2_implicit",
                #"{"implicit":{"authorizationUrl":"https://example.com/oauth/authorize","refreshUrl":"https://example.com/oauth/refresh","scopes":{"read:pets":"Read your pets"}}}"#
            ),
            (
                .password(tokenUrl: tokenURL),
                "oauth2_password",
                #"{"password":{"scopes":{},"tokenUrl":"https://example.com/oauth/token"}}"#
            ),
            (
                .clientCredentials(tokenUrl: tokenURL),
                "oauth2_clientCredentials",
                #"{"clientCredentials":{"scopes":{},"tokenUrl":"https://example.com/oauth/token"}}"#
            ),
            (
                .authorizationCode(authorizationUrl: authorizationURL, tokenUrl: tokenURL),
                "oauth2_authorizationCode",
                #"{"authorizationCode":{"authorizationUrl":"https://example.com/oauth/authorize","scopes":{},"tokenUrl":"https://example.com/oauth/token"}}"#
            ),
            (
                .deviceAuthorization(deviceAuthorizationUrl: authorizationURL, tokenUrl: tokenURL),
                "oauth2_deviceAuthorization",
                #"{"deviceAuthorization":{"deviceAuthorizationUrl":"https://example.com/oauth/authorize","scopes":{},"tokenUrl":"https://example.com/oauth/token"}}"#
            ),
        ]
    )
    func oauth2(flow: OpenAPIAuth.OAuth2Flow, id: String, expected: String) throws {
        let auth = OpenAPIAuth.oauth2(flows: flow)
        #expect(auth.id == id)
        let flows = try #require(oauth2Flows(auth))
        #expect(try json(flows) == expected)
    }

    @Test("Descriptions and the OAuth2 metadata URL are passed through")
    func descriptionsAndMetadata() {
        let auth = OpenAPIAuth.oauth2(
            flows: .password(tokenUrl: tokenURL),
            metadataUrl: openIDURL,
            description: "Pet store OAuth"
        )

        #expect(auth.scheme.type.oauth2MetadataUrl == openIDURL)
        #expect(auth.scheme.description == "Pet store OAuth")
        #expect(OpenAPIAuth.basic(description: "Basic authentication").scheme.description == "Basic authentication")
    }

    @Test("OAuth2 scopes come out sorted by name")
    func oauth2ScopesSorted() throws {
        let auth = OpenAPIAuth.oauth2(
            flows: .clientCredentials(
                tokenUrl: tokenURL,
                scopes: ["write:pets": "Modify", "admin": "Everything", "read:pets": "Read"]
            )
        )
        let scopes = try #require(oauth2Flows(auth)?.clientCredentials?.scopes)

        #expect(Array(scopes.keys) == ["admin", "read:pets", "write:pets"])
        #expect(scopes["admin"] == "Everything")
    }

    // MARK: - Helpers

    private func oauth2Flows(_ auth: OpenAPIAuth) -> OpenAPI.OAuthFlows? {
        guard case .oauth2(let flows, _) = auth.scheme.type else { return nil }
        return flows
    }
}
#endif
