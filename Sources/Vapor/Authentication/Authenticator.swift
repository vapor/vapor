/// Capable of being authenticated.
public protocol Authenticatable { }

public protocol Authenticator {
    associatedtype User: Authenticatable
}

public protocol RequestAuthenticator: Authenticator {
    func authenticate(request: Request) -> EventLoopFuture<User?>
}

// MARK: Basic

public protocol BasicAuthenticator: RequestAuthenticator {
    func authenticate(basic: BasicAuthorization) -> EventLoopFuture<User?>
}

extension BasicAuthenticator {
    public func authenticate(request: Request) -> EventLoopFuture<User?> {
        guard let basicAuthorization = request.headers.basicAuthorization else {
            fatalError()
        }
        return self.authenticate(basic: basicAuthorization)
    }
}

// MARK: Bearer

public protocol BearerAuthenticator: RequestAuthenticator {
    func authenticate(bearer: BearerAuthorization) -> EventLoopFuture<User?>
}

extension BearerAuthenticator {
    public func authenticate(request: Request) -> EventLoopFuture<User?> {
        guard let bearerAuthorization = request.headers.bearerAuthorization else {
            return request.eventLoop.makeSucceededFuture(nil)
        }
        return self.authenticate(bearer: bearerAuthorization)
    }
}

// MARK: User Token

public protocol UserTokenAuthenticator: RequestAuthenticator {
    associatedtype TokenAuthenticator: RequestAuthenticator where
        TokenAuthenticator.User: AuthenticationToken,
        TokenAuthenticator.User.User == User

    var tokenAuthenticator: TokenAuthenticator { get }
    func authenticate(token: TokenAuthenticator.User) -> EventLoopFuture<User?>
}

extension UserTokenAuthenticator {
    public func authenticate(request: Request) -> EventLoopFuture<User?> {
        return self.tokenAuthenticator.authenticate(request: request).flatMap { token in
            guard let token = token else {
                return request.eventLoop.makeSucceededFuture(nil)
            }
            return self.authenticate(token: token)
        }
    }
}

public protocol AuthenticationToken {
    associatedtype User
}

// MARK: Credentials

public protocol CredentialsAuthenticator: RequestAuthenticator {
    associatedtype Credentials: Content
    func authenticate(credentials: Credentials) -> EventLoopFuture<User?>
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
        return self.authenticate(credentials: credentials)
    }
}


// MARK: Middleware

extension RequestAuthenticator {
    public func middleware() -> Middleware {
        return RequestAuthenticationMiddleware<Self>(authenticator: self)
    }
}

private final class RequestAuthenticationMiddleware<A>: Middleware
    where A: RequestAuthenticator
{
    public let authenticator: A

    public init(authenticator: A) {
        self.authenticator = authenticator
    }

    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // if the user has already been authenticated
        // by a previous middleware, continue
        if request.isAuthenticated(A.User.self) {
            return next.respond(to: request)
        }

        // auth user on connection
        return self.authenticator.authenticate(request: request).flatMap { a in
            if let a = a {
                // set authed on request
                request.authenticate(a)
            }
            return next.respond(to: request)
        }
    }
}
