#if OpenAPI
import OpenAPIKit
#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// A security scheme an operation can require, plus the scopes it requires from it.
///
/// We wrap OpenAPIKit's scheme rather than expose it, so OpenAPIKit's major versions don't leak
/// into Vapor's API. Create one with the static factories, such as ``bearer(id:format:description:)``.
public struct OpenAPIAuth: Equatable, Identifiable, Sendable {
    /// The key the scheme is stored under in `components.securitySchemes`.
    ///
    /// When no id is given, one is derived from what the scheme is, such as `http_bearer_JWT`.
    public let id: String

    /// The scopes an operation requires from this scheme.
    ///
    /// These are a subset of the scopes an OAuth2 flow offers, not the catalogue itself.
    public var scopes: [String]

    let scheme: OpenAPI.SecurityScheme

    init(
        id: String?,
        scopes: [String] = [],
        scheme: OpenAPI.SecurityScheme
    ) {
        self.id = id ?? scheme.autoName
        self.scopes = scopes
        self.scheme = scheme
    }

    /// Returns a copy that requires `scopes`, replacing any it already required.
    public func scopes(_ scopes: String...) -> Self {
        self.scopes(scopes)
    }

    /// Returns a copy that requires `scopes`, replacing any it already required.
    public func scopes(_ scopes: [String]) -> Self {
        var result = self
        result.scopes = scopes
        return result
    }

    /// HTTP Basic authentication, with a base64-encoded `username:password` in `Authorization`.
    public static func basic(id: String? = nil, description: String? = nil) -> Self {
        .init(id: id, scheme: .http(scheme: "basic", description: description))
    }

    /// HTTP Bearer authentication, with a token in `Authorization`.
    ///
    /// `format` is a hint for documentation only, such as `JWT`.
    public static func bearer(id: String? = nil, format: String? = nil, description: String? = nil) -> Self {
        .init(id: id, scheme: .http(scheme: "bearer", bearerFormat: format, description: description))
    }

    /// An API key sent as the header, query parameter or cookie called `name`.
    public static func apiKey(id: String? = nil, name: String, in: SecurityLocation = .header, description: String? = nil) -> Self {
        .init(id: id, scheme: .apiKey(name: name, location: `in`.location, description: description))
    }

    /// OAuth2, using the given flow.
    ///
    /// `metadataUrl` points at the authorization server's metadata document (OpenAPI 3.2).
    public static func oauth2(id: String? = nil, flows: OAuth2Flow, metadataUrl: URL? = nil, description: String? = nil) -> Self {
        .init(id: id, scheme: .oauth2(flows: flows.oauthFlow, metadataUrl: metadataUrl, description: description))
    }

    /// OpenID Connect, discovered from the configuration document at `url`.
    public static func openIDConnect(id: String? = nil, url: URL, description: String? = nil) -> Self {
        .init(id: id, scheme: .openIdConnect(url: url, description: description))
    }

    /// Mutual TLS, where the client authenticates with a certificate.
    public static func mutualTLS(id: String? = nil, description: String? = nil) -> Self {
        .init(id: id, scheme: .mutualTLS(description: description))
    }
}

extension OpenAPIAuth {
    /// One OAuth2 flow, with the URLs it uses and the scopes it offers.
    public struct OAuth2Flow: Hashable, Sendable {
        /// The payload is kept behind a wrapper struct rather than exposed as an enum so that new
        /// flows can be added without breaking exhaustive switches downstream.
        enum Base: Hashable, Sendable {
            case implicit(authorizationUrl: URL, refreshUrl: URL?, scopes: [String: String])
            case password(tokenUrl: URL, refreshUrl: URL?, scopes: [String: String])
            case clientCredentials(tokenUrl: URL, refreshUrl: URL?, scopes: [String: String])
            case authorizationCode(authorizationUrl: URL, tokenUrl: URL, refreshUrl: URL?, scopes: [String: String])
            case deviceAuthorization(deviceAuthorizationUrl: URL, tokenUrl: URL, scopes: [String: String])
        }

        let base: Base

        init(base: Base) {
            self.base = base
        }

        /// This flow as OpenAPIKit's `OAuthFlows`, with only this flow set.
        var oauthFlow: OpenAPI.OAuthFlows {
            switch base {
            case .implicit(let authorizationUrl, let refreshUrl, let scopes):
                OpenAPI.OAuthFlows(
                    implicit: .init(authorizationUrl: authorizationUrl, refreshUrl: refreshUrl, scopes: scopes.sortedOrderedDictionary))
            case .password(let tokenUrl, let refreshUrl, let scopes):
                OpenAPI.OAuthFlows(password: .init(tokenUrl: tokenUrl, refreshUrl: refreshUrl, scopes: scopes.sortedOrderedDictionary))
            case .clientCredentials(let tokenUrl, let refreshUrl, let scopes):
                OpenAPI.OAuthFlows(
                    clientCredentials: .init(tokenUrl: tokenUrl, refreshUrl: refreshUrl, scopes: scopes.sortedOrderedDictionary))
            case .authorizationCode(let authorizationUrl, let tokenUrl, let refreshUrl, let scopes):
                OpenAPI.OAuthFlows(
                    authorizationCode: .init(
                        authorizationUrl: authorizationUrl, tokenUrl: tokenUrl, refreshUrl: refreshUrl,
                        scopes: scopes.sortedOrderedDictionary))
            case .deviceAuthorization(let deviceAuthorizationUrl, let tokenUrl, let scopes):
                OpenAPI.OAuthFlows(
                    deviceAuthorization: .init(
                        deviceAuthorizationUrl: deviceAuthorizationUrl, tokenUrl: tokenUrl, scopes: scopes.sortedOrderedDictionary))
            }
        }

        /// The implicit flow, where the token comes straight back from `authorizationUrl`.
        ///
        /// `scopes` maps each scope's name to a description of what it grants.
        public static func implicit(authorizationUrl: URL, refreshUrl: URL? = nil, scopes: [String: String] = [:]) -> Self {
            .init(base: .implicit(authorizationUrl: authorizationUrl, refreshUrl: refreshUrl, scopes: scopes))
        }

        /// The resource owner password flow, exchanging a username and password at `tokenUrl`.
        public static func password(tokenUrl: URL, refreshUrl: URL? = nil, scopes: [String: String] = [:]) -> Self {
            .init(base: .password(tokenUrl: tokenUrl, refreshUrl: refreshUrl, scopes: scopes))
        }

        /// The client credentials flow, for machine-to-machine access at `tokenUrl`.
        public static func clientCredentials(tokenUrl: URL, refreshUrl: URL? = nil, scopes: [String: String] = [:]) -> Self {
            .init(base: .clientCredentials(tokenUrl: tokenUrl, refreshUrl: refreshUrl, scopes: scopes))
        }

        /// The authorization code flow, getting a code from `authorizationUrl` and exchanging it at `tokenUrl`.
        public static func authorizationCode(authorizationUrl: URL, tokenUrl: URL, refreshUrl: URL? = nil, scopes: [String: String] = [:])
            -> Self
        {
            .init(base: .authorizationCode(authorizationUrl: authorizationUrl, tokenUrl: tokenUrl, refreshUrl: refreshUrl, scopes: scopes))
        }

        /// The device authorization flow (OpenAPI 3.2), for devices without a browser.
        public static func deviceAuthorization(deviceAuthorizationUrl: URL, tokenUrl: URL, scopes: [String: String] = [:]) -> Self {
            .init(base: .deviceAuthorization(deviceAuthorizationUrl: deviceAuthorizationUrl, tokenUrl: tokenUrl, scopes: scopes))
        }
    }
}

extension OpenAPIAuth {
    /// Where an API key is sent.
    ///
    /// A plain enum because OpenAPI has only ever allowed these three.
    public enum SecurityLocation: String, Sendable {
        case query
        case header
        case cookie

        var location: OpenAPI.SecurityScheme.Location {
            switch self {
            case .query: .query
            case .header: .header
            case .cookie: .cookie
            }
        }
    }
}

extension OpenAPI.SecurityScheme {
    /// An id derived from what kind of scheme it is, not how it's described, so that different
    /// kinds never share a key in `components.securitySchemes`. Schemes of one kind that differ in
    /// their URLs, such as two OpenID Connect providers, do, and need ids of their own.
    var autoName: String {
        let parts: [String?] =
            switch type {
            case .apiKey(let name, let location):
                [type.name.rawValue, location.rawValue, name]
            case .http(let scheme, let bearerFormat):
                [type.name.rawValue, scheme, bearerFormat]
            case .oauth2(let flows, _):
                [
                    type.name.rawValue,
                    flows.implicit.map { _ in "implicit" },
                    flows.password.map { _ in "password" },
                    flows.clientCredentials.map { _ in "clientCredentials" },
                    flows.authorizationCode.map { _ in "authorizationCode" },
                    flows.deviceAuthorization.map { _ in "deviceAuthorization" },
                ]
            case .openIdConnect, .mutualTLS:
                [type.name.rawValue]
            }
        return
            parts
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .map(\.componentKeySafe)
            .joined(separator: "_")
    }
}

extension Dictionary where Key == String, Value == String {
    /// The dictionary as OpenAPIKit's `OrderedDictionary`, with its keys sorted.
    ///
    /// `JSONEncoder` doesn't keep this order, so stable JSON needs `.sortedKeys` on the encoder.
    var sortedOrderedDictionary: OrderedDictionary<String, String> {
        OrderedDictionary(
            sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

#endif
