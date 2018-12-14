/// A basic, closure-based `Responder`.
public struct BasicResponder: HTTPResponder {
    /// The stored responder closure.
    private let closure: (HTTPRequest) throws -> EventLoopFuture<HTTPResponse>

    /// Create a new `BasicResponder`.
    ///
    ///     let notFound: Responder = BasicResponder { req in
    ///         let res = req.response(http: .init(status: .notFound))
    ///         return req.eventLoop.newSucceededFuture(result: res)
    ///     }
    ///
    /// - parameters:
    ///     - closure: Responder closure.
    public init(closure: @escaping (HTTPRequest) throws -> EventLoopFuture<HTTPResponse>) {
        self.closure = closure
    }

    /// See `Responder`.
    public func respond(to req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        do {
            return try closure(req)
        } catch {
            #warning("TODO: fix force cast")
            return req.channel!.eventLoop.makeFailedFuture(error: error)
        }
    }
}
