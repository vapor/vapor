/// Capable of being authenticated.
public protocol Authenticatable { }

/// Helper for creating authentication middleware.
///
/// See `RequestAuthenticator` and `SessionAuthenticator` for more information.
public protocol Authenticator: Middleware { }

/// Help for creating authentication middleware based on `Request`.
///
/// `Authenticator`'s use the incoming request to check for authentication information.
/// If valid authentication credentials are present, the authenticated user is added to `req.auth`.
public protocol RequestAuthenticator: Authenticator {
    func authenticate(request: Request) -> EventLoopFuture<Void>
}

extension RequestAuthenticator {
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        return self.authenticate(request: request).flatMap {
            next.respond(to: request)
        }
    }
}

// MARK: Basic

/// Helper for creating authentication middleware using the Basic authorization header.
public protocol BasicAuthenticator: RequestAuthenticator {
    func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void>
}

extension BasicAuthenticator {
    public func authenticate(request: Request) -> EventLoopFuture<Void> {
        guard let basicAuthorization = request.headers.basicAuthorization else {
            return request.eventLoop.makeSucceededFuture(())
        }
        return self.authenticate(basic: basicAuthorization, for: request)
    }
}

// MARK: Bearer

/// Helper for creating authentication middleware using the Bearer authorization header.
public protocol BearerAuthenticator: RequestAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void>
}

extension BearerAuthenticator {
    public func authenticate(request: Request) -> EventLoopFuture<Void> {
        guard let bearerAuthorization = request.headers.bearerAuthorization else {
            return request.eventLoop.makeSucceededFuture(())
        }
        return self.authenticate(bearer: bearerAuthorization, for: request)
    }
}

// MARK: Credentials

/// Helper for creating authentication middleware using request body contents.
public protocol CredentialsAuthenticator: RequestAuthenticator {
    associatedtype Credentials: Content
    func authenticate(credentials: Credentials, for request: Request) -> EventLoopFuture<Void>
}

extension CredentialsAuthenticator {
    public func authenticate(request: Request) -> EventLoopFuture<Void> {
        return request.body.collect(max: nil).flatMap { _ -> EventLoopFuture<Void> in
            let credentials: Credentials
            do {
                credentials = try request.content.decode(Credentials.self)
            } catch {
                return request.eventLoop.makeSucceededFuture(())
            }
            return self.authenticate(credentials: credentials, for: request)
        }
    }
}
