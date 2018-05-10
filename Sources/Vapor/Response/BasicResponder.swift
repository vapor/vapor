/// A basic, closure-based `Responder`.
public struct BasicResponder: Responder {
    /// The stored responder closure.
    private let closure: (Request) throws -> Future<Response>

    /// Create a new `BasicResponder`.
    ///
    ///     let notFound: Responder = BasicResponder { req in
    ///         let res = req.response(http: .init(status: .notFound))
    ///         return req.eventLoop.newSucceededFuture(result: res)
    ///     }
    ///
    /// - parameters:
    ///     - closure: Responder closure.
    public init(closure: @escaping (Request) throws -> Future<Response>) {
        self.closure = closure
    }

    /// See `Responder`.
    public func respond(to req: Request) throws -> Future<Response> {
        return try closure(req)
    }
}
