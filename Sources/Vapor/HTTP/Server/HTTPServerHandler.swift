import NIOHTTPServer
import BasicContainers
import HTTPTypes
import HTTPAPIs
package import NIOCore
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
        // 1. Wrap the request body in a lazy pull-based stream (no eager collection).
        let bodyStream = RequestBodyStream(reader: consume reader)
        defer { try? await bodyStream.drain() }

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
                application: self.application,
                method: request.method,
                url: URI(path: rawPath),
                version: .init(major: 1, minor: 1),
                headersNoUpdate: request.headerFields,
                bodyStream: bodyStream,
                remoteAddress: remoteAddress,
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

/// Lazily exposes the server's request body as an `AsyncSequence` of `ByteBuffer`s.
///
/// This is the request-side mirror of ``NIOResponseBodyWriter``: it wraps the server's move-only,
/// non-Sendable `Reader` and pulls one part at a time, so backpressure propagates to the producer
/// (the server stops reading until the handler asks for the next chunk).
///
/// It is `@unchecked Sendable` (not checked): the stored `Reader` is a move-only, non-Sendable type
/// that can't live behind a lock, so the compiler can't verify safety. Safety rests on a contract —
/// **a request body is consumed by a single task**: iterated or collected once, never concurrently.
/// `Request` is `Sendable` so it can cross tasks, but its body must not be read from two of them.
package final class RequestBodyStream: AsyncSequence, @unchecked Sendable {
    package typealias Element = ByteBuffer

    package struct AsyncIterator: AsyncIteratorProtocol {
        let stream: RequestBodyStream

        fileprivate init(stream: RequestBodyStream) {
            self.stream = stream
        }

        package mutating func next() async throws -> ByteBuffer? {
            try await stream.readChunk()
        }
    }

    private var reader: NIOHTTPServer.Reader?
    /// Latches once the body ends so further reads short-circuit instead of touching a spent reader.
    private var finished = false

    init(reader: consuming NIOHTTPServer.Reader) {
        self.reader = consume reader
    }

    package func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: self)
    }

    /// Reads the whole body into one buffer, aborting with 413 if it exceeds `max`.
    func collect(max: Int) async throws -> ByteBuffer {
        var collected = ByteBuffer()
        while let chunk = try await readChunk() {
            // Check before appending so an over-limit chunk is never buffered. Subtracting
            // (rather than adding) keeps the bound exact and can't overflow when `max` is `.max`.
            guard chunk.readableBytes <= max - collected.readableBytes else {
                throw Abort(.contentTooLarge)
            }
            collected.writeBytes(chunk.readableBytesView)
        }
        return collected
    }

    /// Discards any unread body. Needed so an unconsumed request doesn't wedge keep-alive reuse.
    func drain() async throws {
        while try await readChunk() != nil { }
    }

    private func readChunk() async throws -> ByteBuffer? {
        guard !self.finished else {
            return nil
        }
        // The server delivers body and end as separate reads: a body part always has `nil`
        // trailers and carries the bytes, while the end read carries a non-nil `trailers` and an
        // empty buffer. So a non-nil `trailers` means end-of-body with nothing to hand back, and
        // no bytes are lost by returning nil here. The server reuses its buffer across calls, so
        // the bytes are copied out.
        let chunk: ByteBuffer? = try await self.reader?.read { chunk, trailers in
            if trailers != nil {
                return nil
            }
            var byteBuffer = ByteBuffer()
            byteBuffer.writeBytes(chunk.span.bytes)
            return byteBuffer
        }
        if chunk == nil {
            self.finished = true
        }
        return chunk
    }
}
