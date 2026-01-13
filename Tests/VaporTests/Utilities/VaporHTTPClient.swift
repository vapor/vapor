import NIOCore
import AsyncHTTPClient
import Logging
import Foundation
import NIOHTTPTypesHTTP1
import HTTPTypes
import NIOHTTP1
import Vapor

#warning("This is reimported from Vapor. We can remove it once we can enable traits for tests only (https://github.com/swiftlang/swift-package-manager/issues/9523)")
struct VaporHTTPClient: Client {
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
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .init(clientRequest.method)
        request.headers = .init(clientRequest.headers)
        if let requestBody = clientRequest.body {
            request.body = .bytes(requestBody)
        }
        let response = try await self.http.execute(
            request,
            deadline: .now() + clientRequest.timeout,
            logger: self.logger)
        return try await ClientResponse(
            status: .init(code: Int(response.status.code)),
            headers: .init(response.headers, splitCookie: false),
            body: response.body.collect(upTo: clientRequest.maxResponseBodySize),
            byteBufferAllocator: self.byteBufferAllocator,
            contentConfiguration: self.contentConfiguration
        )
    }

    init(http: HTTPClient = .shared, from app: Application) {
        self.http = http
        self.logger = app.logger
        self.byteBufferAllocator = app.byteBufferAllocator
        self.contentConfiguration = app.contentConfiguration
    }
}
