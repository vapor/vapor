import NIOCore

/// `AsyncMiddleware` is placed between the server and your router. It is capable of
/// mutating both incoming requests and outgoing responses. `AsyncMiddleware` can choose
/// to pass requests on to the next `AsyncMiddleware` in a chain, or they can short circuit and
/// return a custom `Response` if desired.
///
/// This is an async version of `Middleware`
public protocol AsyncMiddleware: Middleware {
    /// Called with each `Request` that passes through this middleware.
    /// - parameters:
    ///     - request: The incoming `Request`.
    ///     - next: Next `Responder` in the chain, potentially another middleware or the main router.
    /// - returns: An asynchronous `Response`.
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response
}

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

extension Array where Element == AsyncMiddleware {
    /// Wraps an `AsyncResponder` in an array of `AsyncMiddleware` creating a new `AsyncResponder`.
    /// - note: The array of middleware must be `[AsyncMiddleware]` not `[M] where M: AsyncMiddleware`.
    public func makeAsyncResponder(chainingTo responder: AsyncResponder) -> AsyncResponder {
        var responder = responder
        for middleware in reversed() {
            responder = middleware.makeAsyncResponder(chainingTo: responder)
        }
        return responder
    }
}

public extension AsyncMiddleware {
    /// Wraps a `Responder` in a single `Middleware` creating a new `Responder`.
    func makeAsyncResponder(chainingTo responder: AsyncResponder) -> AsyncResponder {
        return AsyncHTTPMiddlewareResponder(middleware: self, responder: responder)
    }
}

private struct AsyncHTTPMiddlewareResponder: AsyncResponder {
    var middleware: AsyncMiddleware
    var responder: AsyncResponder
    
    init(middleware: AsyncMiddleware, responder: AsyncResponder) {
        self.middleware = middleware
        self.responder = responder
    }
    
    /// Chains an incoming request to another `AsyncResponder` on the router.
    /// - parameters:
    ///     - request: The incoming `Request`.
    /// - returns: An asynchronous `Response`.
    func respond(to request: Request) async throws -> Response {
        return try await self.middleware.respond(to: request, chainingTo: self.responder)
    }
}

struct AsyncMiddlewareWrapper: AsyncMiddleware {
    
    let middleware: Middleware
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        try await middleware.respond(to: request, chainingTo: next).get()
    }
}
