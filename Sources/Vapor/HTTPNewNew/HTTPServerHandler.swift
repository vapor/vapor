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
            switch vaporResponse.body.storage {
            case .stream(let bodyStream):
                // Streaming body: send the head, then let the body closure write chunks straight
                // into the server's writer. The writer is non-Sendable (it wraps the server's
                // move-only response writer), so it stays in this task; each `write` awaits the
                // transport, so backpressure propagates to the closure. The server appends the
                // final chunk via `finish` once the closure returns.
                // Keep the concrete type so we can call `finish` (which is intentionally not part
                // of the public `ResponseBodyWriter` protocol); the closure only sees `write`.
                let writer = NIOResponseBodyWriter(inner: try await sender.send(httpResponse))
                try await bodyStream.callback(writer)
                guard bodyStream.count < 0 || writer.bytesWritten == bodyStream.count else {
                    // Stream lenght is different to what was expecting, this is an error state to close the connection
                    Logger.current.debug(
                        "Response body stream wrote a different number of bytes than it declared, closing the connection",
                        metadata: [
                            "written": "\(writer.bytesWritten)",
                            "declared": "\(bodyStream.count)",
                        ])
                    return
                }
                try await writer.finish(nil)
            default:
                // Buffered body: single-shot write.
                var responseBody = UniqueArray<UInt8>()
                if let buffer = vaporResponse.body.buffer, buffer.readableBytes > 0 {
                    responseBody.append(copying: buffer.readableBytesView)
                }
                try await sender.sendAndFinish(httpResponse, buffer: &responseBody)
            }
        }
    }
}

/// Bridges Vapor's ``ResponseBodyWriter`` onto the server's move-only response writer.
///
/// Each chunk is copied into a `UniqueArray<UInt8>` and forwarded with `await`, so the transport's
/// backpressure (the socket/HTTP-2 flow-control window) propagates straight to the body-stream
/// closure — a fast producer suspends while a slow client catches up. The underlying writer is
/// move-only (`~Copyable`) and ``finish(_:)`` consumes it, so it's stored in an `Optional`: a class
/// can't move a stored property out in place, and `Optional.take()` is how ``finish(_:)`` moves it out.
final class NIOResponseBodyWriter: ResponseBodyWriter {
    private var inner: NIOHTTPServer.ResponseSender.Writer?

    /// The number of body bytes written so far, used to check a stream against its declared length.
    private(set) var bytesWritten = 0

    init(inner: consuming NIOHTTPServer.ResponseSender.Writer) {
        self.inner = consume inner
    }

    func write(_ buffer: ByteBuffer) async throws {
        var out = UniqueArray<UInt8>(minimumCapacity: buffer.readableBytes)
        out.append(copying: buffer.readableBytesView)
        // `inner` is always present during writes (the body closure runs before `finish`, which
        // takes it); the optional-chaining is just how we reach the move-only writer in place.
        try await self.inner?.write(buffer: &out)
        self.bytesWritten += buffer.readableBytes
    }

    func finish(_ trailingHeaders: HTTPFields?) async throws {
        guard let writer = self.inner.take() else { return }
        var empty = UniqueArray<UInt8>()
        try await writer.finish(buffer: &empty, finalElement: trailingHeaders)
    }
}
