import Vapor
import Baggage

struct ResponderClient: Client {
    let responder: Responder
    let application: Application

    var eventLoop: EventLoop {
        self.application.eventLoopGroup.next()
    }

    func delegating(to eventLoop: EventLoop) -> Client {
        self
    }

    func send(_ request: ClientRequest, context: LoggingContext) -> EventLoopFuture<ClientResponse> {
        self.responder.respond(to: .init(
            application: self.application,
            method: request.method,
            url: request.url,
            version: .init(major: 1, minor: 1),
            headersNoUpdate: request.headers,
            collectedBody: request.body,
            remoteAddress: nil,
            logger: application.logger,
            on: application.eventLoopGroup.next()
        )).map { res in
            ClientResponse(status: res.status, headers: res.headers, body: res.body.buffer)
        }
    }
}

extension Application.Clients.Provider {
    static var responder: Self {
        .init {
            $0.clients.use {
                ResponderClient(responder: $0.responder, application: $0)
            }
        }
    }
}
