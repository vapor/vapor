/// A basic, closure-based responder.
public struct BasicResponder: Responder {
    /// Responder closure
    public typealias Closure = (Request) throws -> Future<Response>

    /// The stored responder closure.
    public let closure: Closure

    /// Create a new basic responder.
    public init(closure: @escaping Closure) {
        self.closure = closure
    }

    /// See: .Responder.respond
    public func respond(to req: Request) throws -> Future<Response> {
        return try closure(req)
    }
}
