import Vapor
import NIOCore
import Logging

struct ResponderClient: Client {
    let responder: any Responder
    let application: Application
    let byteBufferAllocator: NIOCore.ByteBufferAllocator
    let contentConfiguration: Vapor.ContentConfiguration

    init(responder: any Responder, application: Application) {
        self.responder = responder
        self.application = application
        self.byteBufferAllocator = application.byteBufferAllocator
        self.contentConfiguration = application.contentConfiguration
    }

    var eventLoop: any EventLoop {
        self.application.eventLoopGroup.next()
    }

    func delegating(to eventLoop: any EventLoop) -> any Client {
        self
    }

    func send(_ request: ClientRequest) async throws -> ClientResponse {
        let res = try await self.responder.respond(to: .init(
            application: self.application,
            method: request.method,
            url: request.url,
            version: .init(major: 1, minor: 1),
            headersNoUpdate: request.headers,
            collectedBody: request.body,
            remoteAddress: nil,
            logger: application.logger,
            on: application.eventLoopGroup.next()
        ))
        return ClientResponse(status: res.status, headers: res.headers, body: res.body.buffer)
    }

    func logging(to logger: Logger) -> any Client {
        self
    }

    func allocating(to byteBufferAllocator: ByteBufferAllocator) -> any Client {
        self
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
