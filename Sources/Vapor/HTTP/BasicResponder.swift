import NIOCore

/// A basic, async closure-based `Responder`.
public struct BasicResponder: Responder {
    /// The stored responder closure.
    private let closure: @Sendable (Request) async throws -> Response

    /// Create a new `BasicResponder`.
    ///
    ///     let notFound: Responder = BasicResponder { req in
    ///         let res = req.response(http: .init(status: .notFound))
    ///         return res
    ///     }
    ///
    /// - parameters:
    ///     - closure: Responder closure.
    public init(
        closure: @Sendable @escaping (Request) async throws -> Response
    ) {
        self.closure = closure
    }

    public func respond(to request: Request) async throws -> Response {
        return try await closure(request)
    }
}
