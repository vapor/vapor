/// A basic, closure-based responder.
public struct BasicResponder: Responder {
    /// The stored responder closure.
    public let closure: (Request) throws -> Future<Response>

    /// Create a new `BasicResponder`.
    public init(closure: @escaping (Request) throws -> Future<Response>) {
        self.closure = closure
    }

    /// See `Responder`.
    public func respond(to req: Request) throws -> Future<Response> {
        return try closure(req)
    }
}
