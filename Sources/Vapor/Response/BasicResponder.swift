/// A basic, closure-based `Responder`.
public struct BasicResponder: Responder {
    /// The stored responder closure.
    private let closure: (HTTPRequestContext) throws -> EventLoopFuture<Response>

    /// Create a new `BasicResponder`.
    ///
    ///     let notFound: Responder = BasicResponder { req in
    ///         let res = req.response(http: .init(status: .notFound))
    ///         return req.eventLoop.newSucceededFuture(result: res)
    ///     }
    ///
    /// - parameters:
    ///     - closure: Responder closure.
    public init(closure: @escaping (HTTPRequestContext) throws -> EventLoopFuture<Response>) {
        self.closure = closure
    }

    /// See `Responder`.
    public func respond(to req: HTTPRequestContext) -> EventLoopFuture<Response> {
        do {
            return try closure(req)
        } catch {
            return req.eventLoop.makeFailedFuture(error: error)
        }
    }
}
