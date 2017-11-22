import Async
import HTTP
import Routing

extension Model where Self: Parameter, ID: StringDecodable {
    /// See Parameter.uniqueSlug
    public static var uniqueSlug: String {
        return "pet"
    }

    /// See Parameter.make
    public static func make(for parameter: String, in req: Request) throws -> Future<Self> {
        guard let id = ID.decode(from: parameter) else {
            throw "could not convert parameter \(parameter) to type `\(ID.self)`"
        }
        return Self.find(id, on: req).map { pet in
            guard let pet = pet else {
                throw "no pet w/ that id was found"
            }

            return pet
        }
    }
}

/// MARK: HTTP

extension Request: ConnectionRepresentable { }

/// Middleware required for certain Fluent features to work correctly.
/// Make sure to add this middleware to your app's MiddlewareConfig.
public final class FluentMiddleware: Middleware {
    /// Creates a new Fluent middleware.
    public init() {}

    /// See Middleware.respond
    public func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        return try next.respond(to: req).map { res in
            try req.releaseConnections()
            return res
        }
    }
}
