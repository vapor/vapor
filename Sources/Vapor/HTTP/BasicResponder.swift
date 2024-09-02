import NIOCore

/// A basic, closure-based `Responder`.
public struct BasicResponder: Responder {
    /// The stored responder closure.
    private let closure: @Sendable (Request) throws -> EventLoopFuture<Response>

    /// Create a new `BasicResponder`.
    ///
    ///     let notFound: Responder = BasicResponder { req in
    ///         let res = req.response(http: .init(status: .notFound))
    ///         return req.eventLoop.newSucceededFuture(result: res)
    ///     }
    ///
    /// - parameters:
    ///     - closure: Responder closure.
    public init(
        closure: @Sendable @escaping (Request) throws -> EventLoopFuture<Response>
    ) {
        self.closure = closure
    }

    /// See `Responder`.
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        do {
            return try closure(request)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}
