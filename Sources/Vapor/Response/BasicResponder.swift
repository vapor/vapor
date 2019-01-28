#warning("TODO: add EventLoop req to HTTPResponder")

/// A basic, closure-based `Responder`.
public struct BasicResponder: Responder {
    private let eventLoop: EventLoop
    
    /// The stored responder closure.
    private let closure: (RequestContext, EventLoop) throws -> EventLoopFuture<HTTPResponse>

    /// Create a new `BasicResponder`.
    ///
    ///     let notFound: Responder = BasicResponder { req in
    ///         let res = req.response(http: .init(status: .notFound))
    ///         return req.eventLoop.newSucceededFuture(result: res)
    ///     }
    ///
    /// - parameters:
    ///     - closure: Responder closure.
    public init(eventLoop: EventLoop, closure: @escaping (RequestContext, EventLoop) throws -> EventLoopFuture<HTTPResponse>) {
        self.eventLoop = eventLoop
        self.closure = closure
    }

    /// See `Responder`.
    public func respond(to req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        do {
            return try closure(req, self.eventLoop)
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
}
