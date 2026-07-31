import NIOCore
import HTTPTypes

/// Protocol for types to conform to that can be authenticated
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

public protocol BasicAuthenticator: RequestAuthenticator {
    /// Realm to advertise in the `WWW-Authenticate` challenge.
    var realm: String { get }

    func authenticate(basic: BasicAuthorization, for request: Request) async throws
}

extension BasicAuthenticator {
    public var realm: String {
        "Vapor"
    }

    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        try await self.respond(to: request, chainingTo: next, advertising: .basic(realm: self.realm))
    }

    public func authenticate(request: Request) async throws {
        guard let basicAuthorization = request.headers.basicAuthorization else {
            return
        }
        return try await self.authenticate(basic: basicAuthorization, for: request)
    }
}

// MARK: Bearer

public protocol BearerAuthenticator: RequestAuthenticator {
    /// Realm to advertise in the `WWW-Authenticate` challenge.
    var realm: String { get }

    func authenticate(bearer: BearerAuthorization, for request: Request) async throws
}

extension BearerAuthenticator {
    public var realm: String {
        "Vapor"
    }

    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        try await self.respond(to: request, chainingTo: next, advertising: .bearer(realm: self.realm))
    }

    public func authenticate(request: Request) async throws {
        guard let bearerAuthorization = request.headers.bearerAuthorization else {
            return
        }
        return try await self.authenticate(bearer: bearerAuthorization, for: request)
    }
}

// MARK: Credentials

public protocol CredentialsAuthenticator: RequestAuthenticator {
    associatedtype Credentials: Content
    func authenticate(credentials: Credentials, for request: Request) async throws
}

extension CredentialsAuthenticator {
    public func authenticate(request: Request) async throws {
        _ = try await request.body.collect(max: nil).get()
        if let credentials = try? await request.content.decode(Credentials.self) {
            try await self.authenticate(credentials: credentials, for: request)
        }
    }
}
