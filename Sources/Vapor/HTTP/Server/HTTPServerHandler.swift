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
        #warning("Need to handle UNIX sockets when HTTP server supports it")
        let remoteAddress = requestContext.remoteAddress.flatMap {
            try? SocketAddress(ipAddress: $0.host, port: $0.port)
        }

        // HTTPRequest.path is the raw request target, already percent-encoded,
        // and includes the query string (e.g. "/foo%20bar?baz=1").
        // Pass it as the sole argument so URI.init takes the path-only parsing
        // branch, which preserves percent encoding rather than double-encoding.
        let rawPath = request.path ?? "/"

        let requestID = request.headerFields[.xRequestId] ?? UUID().uuidString
        var responseSender = Optional(consume responseSender)
        try await withLogger(mergingMetadata: ["request-id": "\(requestID)"]) { _ in
            let vaporRequest = Request(
                method: request.method,
                url: URI(path: rawPath),
                version: .init(major: 1, minor: 1),
                headersNoUpdate: request.headerFields,
                collectedBody: bodyBuffer.readableBytes > 0 ? bodyBuffer : nil,
                remoteAddress: remoteAddress,
                peerCertificateChain: peerCerts,
                requestID: requestID,
                contentConfiguration: application.contentConfiguration,
                defaultMaxBodySize: application.routes.defaultMaxBodySize
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
            // Vapor currently doesn't have an API for informational responses, trying to return one would
            // result in a crash, so bypass that here
            guard vaporResponse.status.kind != .informational else {
                Logger.current.error(
                    "Handler returned an informational status, which cannot be sent as a final response",
                    metadata: ["status": "\(vaporResponse.status.code)"])
                var empty = UniqueArray<UInt8>()
                try await sender.sendAndFinish(HTTPResponse(status: .internalServerError), buffer: &empty)
                return
            }

            // If this is a HEAD request we don't need a body, so write an empty body out and don't
            // waste time going through the response body. `204` and `304` are defined as bodyless
            // too: writing one anyway breaks framing, and the client reads it as the start of the
            // next response.
            let bodyIsForbidden = request.method == .head
                || vaporResponse.status == .noContent
                || vaporResponse.status == .notModified
            guard !bodyIsForbidden else {
                var empty = UniqueArray<UInt8>()
                try await sender.sendAndFinish(httpResponse, buffer: &empty)
                return
            }

            switch vaporResponse.body.storage {
            // A stream some copy of this body already collected is spent: its bytes live in the
            // body's shared cache, so it is serialised down the buffered path below instead of by
            // re-running a callback that would now write nothing.
            case .stream(let bodyStream) where bodyStream.state.collected == nil:
                // Streaming body: send the head, then let the body closure write chunks straight
                // into the server's writer. The writer is non-Sendable (it wraps the server's
                // move-only response writer), so it stays in this task; each `write` awaits the
                // transport, so backpressure propagates to the closure. The server appends the
                // final chunk via `finish` once the closure returns.
                let writer = NIOResponseBodyWriterStorage(inner: try await sender.send(httpResponse))
                let scope = ResponseBodyWriterScope()
                try await bodyStream.callback(NIOResponseBodyWriter(writer, scope: scope))
                guard bodyStream.count == nil || writer.bytesWritten == bodyStream.count else {
                    // Stream length differs from what was declared: an error state, so close the connection
                    Logger.current.debug(
                        "Response body stream wrote a different number of bytes than it declared, closing the connection",
                        metadata: [
                            "written": "\(writer.bytesWritten)",
                            "declared": "\(bodyStream.count.map(String.init) ?? "unknown")",
                        ])
                    return
                }
                try await writer.finish(nil)
            default:
                // Buffered body: single-shot write. Borrowing the body's bytes copies them straight
                // into the server's container - a `.string`/`.data`/`.staticString` body is no
                // longer materialised into an intermediate `ByteBuffer` first.
                var responseBody = UniqueArray<UInt8>(minimumCapacity: vaporResponse.body.count ?? 0)
                try await vaporResponse.body.withStreamingBytes { bytes in
                    bytes.withUnsafeBytes { unsafe responseBody.append(copying: $0) }
                }
                try await sender.sendAndFinish(httpResponse, buffer: &responseBody)
            }
        }
    }
}

/// Holds the server's move-only response writer for the duration of one response.
///
/// The NIO writer is `~Copyable` and ``finish(_:)`` consumes it, so it lives in an `Optional`: a
/// class can't move a stored property out in place, and `Optional.take()` is how it is moved out.
/// This stays a class because the server mutates it across `await` points; the *lent* view handed
/// to user code is the non-escapable ``NIOResponseBodyWriter`` below.
final class NIOResponseBodyWriterStorage {
    private var inner: NIOHTTPServer.ResponseSender.Writer?

    /// The number of body bytes written so far, used to check a stream against its declared length.
    private(set) var bytesWritten = 0

    init(inner: consuming NIOHTTPServer.ResponseSender.Writer) {
        self.inner = consume inner
    }

    func write(_ bytes: RawSpan) async throws {
        // We need to copy here so the writer takes ownership of the data
        // TODO: This should be fixed in HTTP Server to avoid the copy
        var out = UniqueArray<UInt8>(minimumCapacity: bytes.byteCount)
        bytes.withUnsafeBytes { unsafe out.append(copying: $0) }
        try await self.inner?.write(buffer: &out)
        self.bytesWritten += bytes.byteCount
    }

    func write(_ bytes: some Sequence<UInt8>) async throws {
        var out = UniqueArray<UInt8>(minimumCapacity: bytes.underestimatedCount)
        // Staging is synchronous, so the sequence's own storage can be borrowed rather than copied
        // element by element; only the transport write is awaited, after the borrow has ended.
        let borrowed: Void? = bytes.withContiguousStorageIfAvailable { buffer in
            out.append(copying: buffer)
        }
        if borrowed == nil {
            out.append(copying: bytes)
        }
        // `write` drains `out`, so the count has to be taken first.
        let count = out.count
        try await self.inner?.write(buffer: &out)
        self.bytesWritten += count
    }

    func finish(_ trailingHeaders: HTTPFields?) async throws {
        guard let writer = self.inner.take() else { return }
        var empty = UniqueArray<UInt8>()
        try await writer.finish(buffer: &empty, finalElement: trailingHeaders)
    }
}

/// Bridges Vapor's ``ResponseBodyWriter`` onto the server's move-only response writer.
///
/// Each chunk is copied into a `UniqueArray<UInt8>` and forwarded with `await`, so the transport's
/// backpressure (the socket/HTTP-2 flow-control window) propagates straight to the body-stream
/// closure — a fast producer suspends while a slow client catches up.
///
/// Non-escapable, so it cannot outlive the lend: this is what carries the server's move-only
/// guarantee through to user code. See https://github.com/vapor/vapor/issues/2976.
struct NIOResponseBodyWriter: ResponseBodyWriter, ~Escapable {
    private let storage: NIOResponseBodyWriterStorage

    @_lifetime(borrow scope)
    init(_ storage: NIOResponseBodyWriterStorage, scope: borrowing ResponseBodyWriterScope) {
        self.storage = storage
    }

    func write(_ bytes: RawSpan) async throws {
        try await self.storage.write(bytes)
    }

    func write(_ bytes: some Sequence<UInt8>) async throws {
        try await self.storage.write(bytes)
    }
}
