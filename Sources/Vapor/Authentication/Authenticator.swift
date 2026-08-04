import NIOCore
import HTTPTypes

/// A protocol to which a type may conform to enable use of that type for authentication.
public protocol Authenticatable: Sendable { }

/// Helper for creating authentication middleware.
///
/// ``RequestAuthenticator``s use the incoming request to check for authentication information.
/// The authenticator can check credentials (such as in a header) and add the authenticated
/// instance to the request's authentication cache.
///
/// See ``BasicAuthenticator``, ``BearerAuthenticator``, ``CredentialsAuthenticator`` and
/// ``SessionAuthenticator`` built-in implementations
public protocol RequestAuthenticator: Middleware {
    func authenticate(request: Request) async throws
}

extension RequestAuthenticator {
    /// ``Midleware`` conformance to make it easier to use
    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        try await self.authenticate(request: request)
        return try await next.respond(to: request)
    }
}

extension RequestAuthenticator {
    fileprivate func respond(
        to request: Request,
        chainingTo next: any Responder,
        advertising challenge: HTTPFields.WWWAuthenticate
    ) async throws -> Response {
        do {
            try await self.authenticate(request: request)
            let response = try await next.respond(to: request)
            if response.status == .unauthorized, response.headers[.wwwAuthenticate] == nil {
                response.headers.wwwAuthenticate = challenge
            }
            return response
        } catch let error as any AbortError where error.status == .unauthorized && error.headers[.wwwAuthenticate] == nil {
            var headers = error.headers
            headers.wwwAuthenticate = challenge
            var abort = Abort(.unauthorized, headers: headers, reason: error.reason)
            if let debuggable = error as? any DebuggableError {
                abort.identifier = debuggable.identifier
                abort.source = debuggable.source ?? abort.source
            }
            throw abort
        }
    }
}

// MARK: Basic

/// HTTP Basic Auth implementation of ``RequestAuthenticator``. Makes it easy to implement basic auth for your own ``Authenticatable`` types.
public protocol BasicAuthenticator: RequestAuthenticator {
    /// Realm to advertise in the `WWW-Authenticate` challenge.
    var realm: String { get }

    /// Authenticates the supplied basic authorization for this request.
    func authenticate(basic: BasicAuthorization, for request: Request) async throws
}

extension BasicAuthenticator {
    /// Default realm to advertise in the `WWW-Authenticate` challenge.
    public var realm: String {
        "Vapor"
    }

    // See ``Middleware/respond(to:chainingTo:)`` for more information.
    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        try await self.respond(to: request, chainingTo: next, advertising: .basic(realm: self.realm))
    }

    // Default implementation of ``RequestAuthenticator/authenticate(request:)`` that checks for a basic authorization header and calls ``BasicAuthenticator/authenticate(basic:for:)`` if it exists.
    public func authenticate(request: Request) async throws {
        guard let basicAuthorization = request.headers.basicAuthorization else {
            return
        }
        return try await self.authenticate(basic: basicAuthorization, for: request)
    }
}

// MARK: Bearer

// HTTP Bearer Auth implementation of ``RequestAuthenticator``. Makes it easy to implement bearer auth for your own ``Authenticatable`` types.
public protocol BearerAuthenticator: RequestAuthenticator {
    /// Realm to advertise in the `WWW-Authenticate` challenge.
    var realm: String { get }

    /// Authenticates the supplied bearer authorization for this request.
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws
}

extension BearerAuthenticator {
    /// Default realm to advertise in the `WWW-Authenticate` challenge.
    public var realm: String {
        "Vapor"
    }

    // See ``Middleware/respond(to:chainingTo:)`` for more information.
    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        try await self.respond(to: request, chainingTo: next, advertising: .bearer(realm: self.realm))
    }

    // Default implementation of ``RequestAuthenticator/authenticate(request:)`` that checks for a bearer authorization header and calls ``BearerAuthenticator/authenticate(bearer:for:)`` if it exists.
    public func authenticate(request: Request) async throws {
        guard let bearerAuthorization = request.headers.bearerAuthorization else {
            return
        }
        return try await self.authenticate(bearer: bearerAuthorization, for: request)
    }
}

// MARK: Credentials

/// Protocol for authenticators that use a credentials type to authenticate. See ``CredentialsAuthenticator`` for more information. Designed for use with HTML forms, works with JSON as well
public protocol CredentialsAuthenticator: RequestAuthenticator {
    /// The credentials type to decode from the request body. Must conform to ``Content``.
    associatedtype Credentials: Content
    /// Authenticates the supplied credentials for this request.
    func authenticate(credentials: Credentials, for request: Request) async throws
}

extension CredentialsAuthenticator {
    /// Default implementation of ``RequestAuthenticator/authenticate(request:)`` that checks for a credentials type in the request body and calls ``CredentialsAuthenticator/authenticate(credentials:for:)`` if it exists.
    public func authenticate(request: Request) async throws {
        _ = try await request.body.collect(max: nil).get()
        if let credentials = try? await request.content.decode(Credentials.self) {
            try await self.authenticate(credentials: credentials, for: request)
        }
    }
}
