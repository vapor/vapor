#if HTTPClient
import NIOCore
import AsyncHTTPClient
import Logging
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOHTTPTypesHTTP1
import HTTPTypes
import NIOHTTP1

internal struct VaporHTTPClient: Client {
    let http: HTTPClient
    let contentConfiguration: ContentConfiguration

    func send(_ clientRequest: ClientRequest) async throws -> ClientResponse {
        let urlString = clientRequest.url.string
        guard let url = URL(string: urlString) else {
            Logger.current.debug("\(urlString) is an invalid URL")
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
            logger: Logger.current)
        // Wrapping AHC's body ourselves means losing its `collect(upTo:)` size check, so the declared
        // length is rejected here instead - before a byte is read, as AHC did.
        let declaredLength = response.headers.first(name: "content-length").flatMap(Int.init)
        if let declaredLength, declaredLength > clientRequest.maxResponseBodySize {
            Logger.current.debug(
                "Response body is larger than the configured maximum",
                metadata: [
                    "declared": "\(declaredLength)",
                    "maximum": "\(clientRequest.maxResponseBodySize)",
                ])
            throw Abort(.contentTooLarge)
        }
        return ClientResponse(
            status: .init(code: Int(response.status.code)),
            headers: .init(response.headers, splitCookie: false),
            // Declaring the length lets a proxied response keep its `Content-Length` instead of
            // being re-framed as chunked. `nil` when the origin did not say.
            body: try .init(stream: { writer in
                for try await chunk in response.body {
                    try await writer.write(chunk.readableBytesSpan)
                }
            }, count: declaredLength),
            maxBodySize: clientRequest.maxResponseBodySize,
            contentConfiguration: self.contentConfiguration
        )
    }
}
#endif
