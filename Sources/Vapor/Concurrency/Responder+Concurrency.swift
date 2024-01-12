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

struct AsyncResponderWrapper: AsyncResponder {
    let responder: Responder
    
    init(_ responder: Responder) {
        self.responder = responder
    }
    
    func respond(to request: Request) async throws -> Response {
        try await self.responder.respond(to: request).get()
    }
}
