import NIOHTTPServer
import BasicContainers
import HTTPTypes
import HTTPAPIs
import NIOCore
import NIOHTTP1
import NIOConcurrencyHelpers
import Logging
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Bridges NIOHTTPServer's request handler protocol into Vapor's responder chain.
struct VaporHTTPServerHandler: HTTPServerRequestHandler {
    typealias RequestContext = NIOHTTPServer.RequestContext
    typealias Reader = NIOHTTPServer.Reader
    typealias ResponseSender = NIOHTTPServer.ResponseSender

    let application: Application
    let responder: any Responder

    func handle(
        request: HTTPRequest,
        requestContext: consuming NIOHTTPServer.RequestContext,
        reader: consuming sending NIOHTTPServer.Reader,
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        // 1. Eagerly collect the full request body
        var reader = reader
        var bodyBuffer = ByteBuffer()
        var reachedEndOfBody = false
        while !reachedEndOfBody {
            // A non-nil outer optional marks the final chunk; the inner value is the trailers.
            try await reader.read { chunk, trailers in
                if !chunk.isEmpty {
                    bodyBuffer.writeBytes(chunk.span.bytes)
                }
                if trailers != nil {
                    reachedEndOfBody = true
                }
            }
        }

        // 2. Build Vapor request
        let peerCerts = try? await requestContext.peerCertificateChain

        // HTTPRequest.path is the raw request target, already percent-encoded,
        // and includes the query string (e.g. "/foo%20bar?baz=1").
        // Pass it as the sole argument so URI.init takes the path-only parsing
        // branch, which preserves percent encoding rather than double-encoding.
        let rawPath = request.path ?? "/"

        let requestID = request.headerFields[.xRequestId] ?? UUID().uuidString
        var responseSender = Optional(consume responseSender)
        try await withLogger(mergingMetadata: ["request-id": "\(requestID)"]) { _ in
            let vaporRequest = Request(
                application: self.application,
                method: request.method,
                url: URI(path: rawPath),
                version: .init(major: 1, minor: 1),
                headersNoUpdate: request.headerFields,
                collectedBody: bodyBuffer.readableBytes > 0 ? bodyBuffer : nil,
                remoteAddress: nil,
                peerCertificateChain: peerCerts,
                byteBufferAllocator: self.application.byteBufferAllocator,
                requestID: requestID
            )

            // 3. Run responder chain
            let vaporResponse = try await responder.respond(to: vaporRequest)
            let httpResponse = HTTPResponse(
                status: vaporResponse.status,
                headerFields: vaporResponse.headers
            )

            // 4. Send the response head and body
            guard let sender = responseSender.take() else {
                Logger.current.critical("Invalid server state - no response sender")
                throw Abort(.internalServerError)
            }
            // TODO: Handle streaming response bodies
            var responseBody = UniqueArray<UInt8>()
            if let buffer = vaporResponse.body.buffer, buffer.readableBytes > 0 {
                responseBody.append(copying: buffer.readableBytesView)
            }
            try await sender.sendAndFinish(httpResponse, buffer: &responseBody)
        }
    }
}
