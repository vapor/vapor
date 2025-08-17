import NIOCore
import AsyncHTTPClient
import Logging
import Foundation

internal struct VaporHTTPClient: Client {
    let http: HTTPClient
    var logger: Logger
    var byteBufferAllocator: ByteBufferAllocator
    let contentConfiguration: ContentConfiguration

    func send(_ clientRequest: ClientRequest) async throws -> ClientResponse {
        let urlString = clientRequest.url.string
        guard let url = URL(string: urlString) else {
            self.logger.debug("\(urlString) is an invalid URL")
            throw Abort(.internalServerError, reason: "\(urlString) is an invalid URL")
        }
        let request = try HTTPClient.Request(
            url: url,
            method: .init(clientRequest.method),
            headers: .init(clientRequest.headers),
            body: clientRequest.body.map { .byteBuffer($0) }
        )
        let response = try await self.http.execute(
            request: request,
            deadline: clientRequest.timeout.map { .now() + $0 },
            logger: logger,
        ).get()
        return ClientResponse(
            status: .init(code: Int(response.status.code)),
            headers: .init(response.headers, splitCookie: false),
            body: response.body,
            byteBufferAllocator: self.byteBufferAllocator,
            contentConfiguration: self.contentConfiguration
        )
    }
}
