#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

/// `AsyncMiddleware` is placed between the server and your router. It is capable of
/// mutating both incoming requests and outgoing responses. `AsyncMiddleware` can choose
/// to pass requests on to the next `AsyncMiddleware` in a chain, or they can short circuit and
/// return a custom `Response` if desired.
///
/// This is an async version of `Middleware`
@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public protocol AsyncMiddleware: Middleware {
    /// Called with each `Request` that passes through this middleware.
    /// - parameters:
    ///     - request: The incoming `Request`.
    ///     - next: Next `Responder` in the chain, potentially another middleware or the main router.
    /// - returns: An asynchronous `Response`.
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension AsyncMiddleware {
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        let promise = request.eventLoop.makePromise(of: Response.self)
        promise.completeWithTask {
            let asyncResponder = AsyncBasicResponder { req in
                return try await next.respond(to: req).get()
            }
            return try await respond(to: request, chainingTo: asyncResponder)
        }
        return promise.futureResult
    }
}

#endif
