import NIOCore
import HTTPTypes

/// Capable of being authenticated.
public protocol Authenticatable: Sendable { }

/// Helper for creating authentication middleware.
///
/// See ``RequestAuthenticator`` and ``SessionAuthenticator`` for more information.
public protocol Authenticator: Middleware { }

/// Help for creating authentication middleware based on ``Request``.
///
/// ``Authenticator``'s use the incoming request to check for authentication information.
/// If valid authentication credentials are present, the authenticated user is added to `req.auth`.
public protocol RequestAuthenticator: Authenticator {
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

/// Helper for creating authentication middleware using the Basic authorization header.
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

/// Helper for creating authentication middleware using the Bearer authorization header.
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

// MARK: Closure-based authenticators

extension Authenticatable {
    /// Creates an authenticator for the Basic authorization header from a closure.
    ///
    /// Returning a value from the closure authenticates it for the request; returning `nil` leaves
    /// the request unauthenticated.
    ///
    /// ```swift
    /// app.grouped(User.basicAuthenticator { basic, request in
    ///     try await User.find(username: basic.username, password: basic.password, on: request.db)
    /// })
    /// ```
    ///
    /// Conform to ``BasicAuthenticator`` directly if you need to authenticate more than one type.
    public static func basicAuthenticator(
        realm: String = "Vapor",
        _ authenticate: @Sendable @escaping (BasicAuthorization, Request) async throws -> Self?
    ) -> any Authenticator {
        ClosureBasicAuthenticator(realm: realm, closure: authenticate)
    }

    /// Creates an authenticator for the Bearer authorization header from a closure.
    ///
    /// Returning a value from the closure authenticates it for the request; returning `nil` leaves
    /// the request unauthenticated.
    ///
    /// ```swift
    /// app.grouped(User.bearerAuthenticator { bearer, request in
    ///     try await User.find(token: bearer.token, on: request.db)
    /// })
    /// ```
    ///
    /// Conform to ``BearerAuthenticator`` directly if you need to authenticate more than one type.
    public static func bearerAuthenticator(
        realm: String = "Vapor",
        _ authenticate: @Sendable @escaping (BearerAuthorization, Request) async throws -> Self?
    ) -> any Authenticator {
        ClosureBearerAuthenticator(realm: realm, closure: authenticate)
    }
}

private struct ClosureBasicAuthenticator<User: Authenticatable>: BasicAuthenticator {
    let realm: String
    let closure: @Sendable (BasicAuthorization, Request) async throws -> User?

    func authenticate(basic: BasicAuthorization, for request: Request) async throws {
        if let user = try await self.closure(basic, request) {
            request.auth.login(user)
        }
    }
}

private struct ClosureBearerAuthenticator<User: Authenticatable>: BearerAuthenticator {
    let realm: String
    let closure: @Sendable (BearerAuthorization, Request) async throws -> User?

    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        if let user = try await self.closure(bearer, request) {
            request.auth.login(user)
        }
    }
}

// MARK: Credentials

/// Helper for creating authentication middleware using request body contents.
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
