import NIOCore
import AsyncHTTPClient
import Logging
import Foundation

extension HTTPClient {
    func delegating(to eventLoop: EventLoop, logger: Logger, byteBufferAllocator: ByteBufferAllocator, contentConfiguration: ContentConfiguration) -> Client {
        EventLoopHTTPClient(
            http: self,
            eventLoop: eventLoop,
            logger: logger,
            byteBufferAllocator: byteBufferAllocator,
            contentConfiguration: contentConfiguration
        )
    }
}

private struct EventLoopHTTPClient: Client {
    let http: HTTPClient
    let eventLoop: EventLoop
    var logger: Logger?
    var byteBufferAllocator: ByteBufferAllocator
    let contentConfiguration: ContentConfiguration

    func send(_ clientRequest: ClientRequest) async throws -> ClientResponse {
        let urlString = clientRequest.url.string
        guard let url = URL(string: urlString) else {
            self.logger?.debug("\(urlString) is an invalid URL")
            throw Abort(.internalServerError, reason: "\(urlString) is an invalid URL")
        }
        let request = try HTTPClient.Request(
            url: url,
            method: clientRequest.method,
            headers: clientRequest.headers,
            body: clientRequest.body.map { .byteBuffer($0) }
        )
        let response = try await self.http.execute(
            request: request,
            eventLoop: .delegate(on: self.eventLoop),
            deadline: clientRequest.timeout.map { .now() + $0 },
            logger: logger
        ).get()
        return ClientResponse(
            status: response.status,
            headers: response.headers,
            body: response.body,
            byteBufferAllocator: self.byteBufferAllocator,
            contentConfiguration: self.contentConfiguration
        )
    }
    
    func logging(to logger: Logger) -> Client {
        return EventLoopHTTPClient(http: self.http, eventLoop: self.eventLoop, logger: self.logger, byteBufferAllocator: self.byteBufferAllocator, contentConfiguration: self.contentConfiguration)
    }

    func allocating(to byteBufferAllocator: ByteBufferAllocator) -> Client {
        return EventLoopHTTPClient(http: self.http, eventLoop: self.eventLoop, logger: self.logger, byteBufferAllocator: self.byteBufferAllocator, contentConfiguration: self.contentConfiguration)
    }
}
