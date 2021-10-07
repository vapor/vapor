#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

/// Helper for creating authentication middleware.
///
/// See `AsyncRequestAuthenticator` and `AsyncSessionAuthenticator` for more information.
///
/// This is an async version of `Authenticator`
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public protocol AsyncAuthenticator: AsyncMiddleware { }

/// Help for creating authentication middleware based on `Request`.
///
/// `Authenticator`'s use the incoming request to check for authentication information.
/// If valid authentication credentials are present, the authenticated user is added to `req.auth`.
///
/// This is an async version of `RequestAuthenticator`
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public protocol AsyncRequestAuthenticator: AsyncAuthenticator {
    func authenticate(request: Request) async throws
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension AsyncRequestAuthenticator {
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        try await self.authenticate(request: request)
        return try await next.respond(to: request)
    }
}

// MARK: Basic

/// Helper for creating authentication middleware using the Basic authorization header.
///
/// This is an async version of `BasicAuthenticator`
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public protocol AsyncBasicAuthenticator: AsyncRequestAuthenticator {
    func authenticate(basic: BasicAuthorization, for request: Request) async throws
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension AsyncBasicAuthenticator {
    public func authenticate(request: Request) async throws {
        guard let basicAuthorization = request.headers.basicAuthorization else {
            return
        }
        return try await self.authenticate(basic: basicAuthorization, for: request)
    }
}

// MARK: Bearer

/// Helper for creating authentication middleware using the Bearer authorization header.
///
/// This is an async version of `BearerAuthenticator`
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public protocol AsyncBearerAuthenticator: RequestAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension AsyncBearerAuthenticator {
    public func authenticate(request: Request) async throws {
        guard let bearerAuthorization = request.headers.bearerAuthorization else {
            return
        }
        return try await self.authenticate(bearer: bearerAuthorization, for: request)
    }
}

// MARK: Credentials

/// Helper for creating authentication middleware using request body contents.
///
/// This is an async version of `CredentialsAuthenticator`
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public protocol AsyncCredentialsAuthenticator: RequestAuthenticator {
    associatedtype Credentials: Content
    func authenticate(credentials: Credentials, for request: Request) async throws
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension AsyncCredentialsAuthenticator {
    public func authenticate(request: Request) async throws {
        let credentials: Credentials
        do {
            credentials = try request.content.decode(Credentials.self)
        } catch {
            return
        }
        return try await self.authenticate(credentials: credentials, for: request)
    }
}

/// Helper for creating authentication middleware in conjunction with `SessionsMiddleware`.
///
/// This is an async version of `SessionAuthenticator`
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public protocol AsyncSessionAuthenticator: Authenticator {
    associatedtype User: SessionAuthenticatable

    /// Authenticate a model with the supplied ID.
    func authenticate(sessionID: User.SessionID, for request: Request) async throws
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension AsyncSessionAuthenticator {
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // if the user has already been authenticated
        // by a previous middleware, continue
        if request.auth.has(User.self) {
            return try await next.respond(to: request)
        }

        if let aID = request.session.authenticated(User.self) {
            // try to find user with id from session
            try await self.authenticate(sessionID: aID, for: request)
        }
        
        // respond to the request
        let response = try await next.respond(to: request)
        if let user = request.auth.get(User.self) {
            // if a user has been authed (or is still authed), store in the session
            request.session.authenticate(user)
        } else if request.hasSession {
            // if no user is authed, it's possible they've been unauthed.
            // remove from session.
            request.session.unauthenticate(User.self)
        }
        return response
    }
}

#endif
