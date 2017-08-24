import Core
import HTTP

/// Capable of registering sync routes.
public protocol SyncRouter: Router { }

extension SyncRouter {
    /// Registers a route handler at the supplied path.
    public func on(_ method: Method, to path: PathComponentRepresentable..., use closure: @escaping BasicSyncResponder.Closure) {
        let responder = BasicSyncResponder(closure: closure)
        self.register(
            responder: responder,
            at: [.constant(method.string)] + path.makePathComponents()
        )
    }
}

/// A basic, closure-based responder.
public struct BasicSyncResponder: Responder {
    /// Responder closure
    public typealias Closure = (Request) throws -> ResponseRepresentable
    
    /// The stored responder closure.
    public let closure: Closure

    /// Create a new basic responder.
    public init(closure: @escaping Closure) {
        self.closure = closure
    }

    /// See: HTTP.Responder.respond
    public func respond(to req: Request) throws -> Future<Response> {
        let res = try closure(req).makeResponse()
        let promise = Promise<Response>()
        promise.complete(res)
        return promise.future
    }
}

