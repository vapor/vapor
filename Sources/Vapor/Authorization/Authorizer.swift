/// Capable of being authorized.
public protocol Authorizable { }

public protocol Authorizer { }

public protocol RequestAuthorizer: Authorizer, Middleware {
    func authorize(request: Request) -> EventLoopFuture<Void>
}

public protocol ParameterAuthorizer: RequestAuthorizer {
    associatedtype Value: LosslessStringConvertible
    var name: String { get }
    func authorize(parameter: Value, for request: Request) -> EventLoopFuture<Void>
}

extension ParameterAuthorizer {
    public func authorize(request: Request) -> EventLoopFuture<Void> {
        guard let parameter = request.parameters.get(self.name, as: Value.self) else {
            request.logger.error("Authorization: Missing parameter: \(self.name)")
            return request.eventLoop.makeFailedFuture(Abort(.forbidden))
        }
        return self.authorize(parameter: parameter, for: request)
    }
}

extension RequestAuthorizer {
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        self.authorize(request: request).flatMap { _ in
            next.respond(to: request)
        }
    }
}

public protocol RoleAuthorizable: Authenticatable {
    associatedtype Role: Equatable, Authorizable
    var role: Role { get }
}

extension RoleAuthorizable {
    public static func authorizer(roles: Role...) -> RoleAuthorizer<Self> {
        .init(roles: roles)
    }
    public static func authorizer(role: Role) -> RoleAuthorizer<Self> {
        .init(roles: [role])
    }
    public static func authorizer(roles: [Role]) -> RoleAuthorizer<Self> {
        .init(roles: roles)
    }
}

public struct RoleAuthorizer<User>: RequestAuthorizer
    where User: RoleAuthorizable
{
    let roles: [User.Role]

    internal init(roles: [User.Role]) {
        self.roles = roles
    }

    public func authorize(request: Request) -> EventLoopFuture<Void> {
        do {
            let user = try request.authc.require(User.self)
            guard self.roles.contains(user.role) else {
                throw Abort(.forbidden)
            }
            request.authz.add(user.role)
            return request.eventLoop.makeSucceededFuture(())
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}
