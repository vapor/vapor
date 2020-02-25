/// Capable of being authenticated.
public protocol Authenticatable { }

public protocol Authenticator {
    associatedtype User: Authenticatable
}

public protocol RequestAuthenticator: Authenticator, Middleware {
    func authenticate(request: Request) -> EventLoopFuture<User?>
}

extension RequestAuthenticator {
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // if the user has already been authenticated
        // by a previous middleware, continue
        if request.authc.has(User.self) {
            return next.respond(to: request)
        }

        // auth user on connection
        return self.authenticate(request: request).flatMap { a in
            if let a = a {
                // set authed on request
                request.authc.login(a)
            }
            return next.respond(to: request)
        }
    }
}

// MARK: Basic

public protocol BasicAuthenticator: RequestAuthenticator {
    func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<User?>
}

extension BasicAuthenticator {
    public func authenticate(request: Request) -> EventLoopFuture<User?> {
        guard let basicAuthorization = request.headers.basicAuthorization else {
            return request.eventLoop.makeSucceededFuture(nil)
        }
        return self.authenticate(basic: basicAuthorization, for: request)
    }
}

// MARK: Bearer

public protocol BearerAuthenticator: RequestAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<User?>
}

extension BearerAuthenticator {
    public func authenticate(request: Request) -> EventLoopFuture<User?> {
        guard let bearerAuthorization = request.headers.bearerAuthorization else {
            return request.eventLoop.makeSucceededFuture(nil)
        }
        return self.authenticate(bearer: bearerAuthorization, for: request)
    }
}

// MARK: Credentials

public protocol CredentialsAuthenticator: RequestAuthenticator {
    associatedtype Credentials: Content
    func authenticate(credentials: Credentials, for request: Request) -> EventLoopFuture<User?>
}

extension CredentialsAuthenticator {
    public func authenticate(request: Request) -> EventLoopFuture<User?> {
        let credentials: Credentials
        do {
            credentials = try request.content.decode(Credentials.self)
        } catch {
            request.logger.error("Could not decode credentials: \(error)")
            return request.eventLoop.makeSucceededFuture(nil)
        }
        return self.authenticate(credentials: credentials, for: request)
    }
}
