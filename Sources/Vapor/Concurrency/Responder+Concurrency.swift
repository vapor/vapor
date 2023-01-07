#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol AsyncResponder: Responder {
    func respond(to request: Request) async throws -> Response
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
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
