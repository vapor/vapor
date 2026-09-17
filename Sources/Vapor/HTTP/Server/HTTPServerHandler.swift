import NIOHTTPServer
import BasicContainers
import HTTPTypes
import HTTPAPIs
import NIOCore
import NIOHTTP1
import Synchronization
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

    let context: ServerContext
    let responder: any Responder

    func handle(
        request: HTTPRequest,
        requestContext: consuming NIOHTTPServer.RequestContext,
        reader: consuming sending NIOHTTPServer.Reader,
        responseSender: consuming sending NIOHTTPServer.ResponseSender
    ) async throws {
        let bodyStream = RequestBodyStream(reader: consume reader)

        // 1. Drain any body the handler didn't read so the keep-alive connection stays usable. GET/HEAD
        // aren't expected to carry a body, so their budget is 0: a body-less request drains nothing
        // (just reads `.end`), and one that does carry a body is left unread, closing the connection.
        let drainLimit = (request.method == .get || request.method == .head)
            ? 0
            : context.configuration.value.maxDrainBytes

        defer { try? await bodyStream.drain(max: drainLimit) }

        // 2. Build Vapor request
        let peerCerts = requestContext.validatedPeerCertificateChain
        let remoteAddress = requestContext.remoteAddress.flatMap { SocketAddress($0) }
        let localAddress = requestContext.localAddress.flatMap { SocketAddress($0) }

        // HTTPRequest.path is the raw request target, already percent-encoded,
        // and includes the query string (e.g. "/foo%20bar?baz=1").
        // Pass it as the sole argument so URI.init takes the path-only parsing
        // branch, which preserves percent encoding rather than double-encoding.
        let rawPath = request.path ?? "/"

        let requestID = request.headerFields[.xRequestId] ?? UUID().uuidString
        var responseSender = Optional(consume responseSender)
        do {
            try await withLogger(mergingMetadata: ["request-id": "\(requestID)"]) { _ in
                let vaporRequest = Request(
                    method: request.method,
                    url: URI(path: rawPath),
                    version: .init(major: 1, minor: 1),
                    headersNoUpdate: request.headerFields,
                    bodyStream: bodyStream,
                    remoteAddress: remoteAddress,
                    localAddress: localAddress,
                    peerCertificateChain: peerCerts,
                    requestID: requestID,
                    contentConfiguration: context.contentConfiguration,
                    defaultMaxBodySize: context.defaultMaxBodySize
                )

                // 3. Run responder chain
                let vaporResponse = try await responder.respond(to: vaporRequest)

                // A body read that failed at the transport surfaces in the responder chain as an error,
                // and the error middleware answers it with a response of its own. The connection that
                // response would go out on is already being torn down, though: NIO answered the parser
                // error with its own 400, below the server's keep-alive handler, and closed the channel.
                // Writing now races NIO's deferred handler removal, and if the write lands first the
                // keep-alive handler pushes a second response head into a pipeline that has already sent
                // one, which NIO asserts on. Return without responding instead: the server logs an
                // unconcluded response and closes the connection, which is where it was going anyway.
                // The `catch` below does the same for a handler that rethrows the failure rather than
                // answering it.
                guard !bodyStream.transportFailed else {
                    Logger.current.debug(
                        "Request ended without a response because its connection is gone",
                        metadata: ["request-id": "\(requestID)", "status": "\(vaporResponse.status.code)"])
                    return
                }

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
                    let writer = NIOHTTPBodyWriterStorage(inner: try await sender.send(httpResponse))
                    let scope = HTTPBodyWriterScope()
                    do {
                        try await bodyStream.callback(NIOHTTPBodyWriter(writer, scope: scope))
                    } catch {
                        // Throwing out of the handler is how the server is told to abort: it closes the
                        // connection without a terminating chunk, so the client sees a truncated body.
                        // Finishing here would send one and present a partial body as a whole one.
                        writer.abandon()
                        throw error
                    }
                    if let declared = bodyStream.count, writer.bytesWritten != declared {
                        // The body did not match the length the head promised. Throw rather than return:
                        // a handler that returns with its response unfinished only has its connection torn
                        // down as inconsistent, whereas a thrown error drives the server's abort.
                        //
                        // Logged here as well as by the server, because the server's log line does not
                        // carry this request's ID.
                        Logger.current.debug(
                            "Response body stream wrote a different number of bytes than it declared, closing the connection",
                            metadata: [
                                "written": "\(writer.bytesWritten)",
                                "declared": "\(declared)",
                            ])
                        writer.abandon()
                        throw ResponseBodyLengthMismatch(declared: declared, written: writer.bytesWritten)
                    }
                    try await writer.finish(nil)
                default:
                    // Buffered body: single-shot write. Borrowing the body's bytes copies them straight
                    // into the server's container - a `.string`/`.data`/`.staticString` body is no
                    // longer materialised into an intermediate `ByteBuffer` first.
                    var responseBody = UniqueArray<UInt8>(minimumCapacity: vaporResponse.body.count ?? 0)
                    try await vaporResponse.body.withStreamingBytes { bytes in
                        responseBody.append(copying: bytes)
                    }
                    try await sender.sendAndFinish(httpResponse, buffer: &responseBody)
                }
            }
        } catch {
            // A throw out of here tells the server to abort the exchange, and for HTTP/1.1 that means writing
            // a response head if it believes none was written. Once the request body's transport has failed
            // the connection is already being torn down: NIO answered the parser error with its own 400,
            // below the server's keep-alive handler, and closed the channel. Nothing is left to abort, and
            // asking for one races NIO's deferred handler removal; if the abort lands first, the keep-alive
            // handler writes a second response head into a pipeline that already sent one, which NIO
            // asserts on. A cancelled task is in the same position. Return instead: the server logs an
            // unconcluded response and closes the connection, which is where it was going anyway.
            guard !bodyStream.transportFailed, !Task.isCancelled else {
                Logger.current.debug(
                    "Request ended without a response because its connection is gone",
                    metadata: ["request-id": "\(requestID)", "error": "\(error)"])
                return
            }
            throw error
        }
    }
}

/// A streaming response body that wrote a different number of bytes than it declared.
///
/// Thrown out of the request handler only to make the server abort the response. The server logs it
/// but never hands it on to a caller, so it carries nothing beyond what that log line needs.
struct ResponseBodyLengthMismatch: Error, CustomStringConvertible {
    let declared: Int
    let written: Int

    var description: String {
        "Response body stream declared \(self.declared) bytes but wrote \(self.written)"
    }
}

extension HTTPFields {
    /// `Connection: close`, for the response to a request whose body we have decided not to finish
    /// reading — a 413, in practice.
    ///
    /// The rest of that body is still on the wire, and the drain that runs once the handler returns is
    /// bounded by `maxDrainBytes`: anything larger leaves the request unread, and the server then hangs
    /// up. The response head is long gone by that point, so the decision has to be made here, when the
    /// error is thrown. Without it the client is handed keep-alive framing and then cut off, and fails
    /// the upload it has already been answered rather than reading the answer.
    static let connectionClose: HTTPFields = {
        var fields = HTTPFields()
        fields.connection = .close
        return fields
    }()
}
