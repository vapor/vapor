import Async
import HTTP

/// A basic, closure-based responder.
public struct BasicResponder<F: FutureType>: Responder where F.Expectation: ResponseRepresentable {
    /// Responder closure
    public typealias Closure = (Request) throws -> F

    /// The stored responder closure.
    public let closure: Closure

    /// Create a new basic responder.
    public init(closure: @escaping Closure) {
        self.closure = closure
    }

    /// See: HTTP.Responder.respond
    public func respond(to req: Request) throws -> Future<Response> {
        return try closure(req).map { rep in
            return try rep.makeResponse(for: req)
        }
    }
}

