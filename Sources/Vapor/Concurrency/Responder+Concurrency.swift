#if canImport(_Concurrency)
import NIOCore

public protocol AsyncResponder: Responder {
    func respond(to request: Request) async throws -> Response
}

extension AsyncResponder {
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        let promise = request.eventLoop.makePromise(of: Response.self)
        promise.completeWithTask {
            try await self.respond(to: request)
        }
        return promise.futureResult
    }
}

#endif
