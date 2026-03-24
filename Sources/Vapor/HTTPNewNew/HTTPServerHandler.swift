import NIOHTTPServer
import HTTPTypes
import HTTPAPIs
import NIOCore
import NIOHTTP1
import NIOConcurrencyHelpers
import Logging

/// Bridges NIOHTTPServer's request handler protocol into Vapor's responder chain.
struct VaporHTTPServerHandler: HTTPServerRequestHandler {
    typealias RequestReader = HTTPRequestConcludingAsyncReader
    typealias ResponseWriter = HTTPResponseConcludingAsyncWriter

    let application: Application
    let responder: any Responder

    func handle(
        request: HTTPRequest,
        requestContext: HTTPRequestContext,
        requestBodyAndTrailers: consuming sending HTTPRequestConcludingAsyncReader,
        responseSender: consuming sending HTTPResponseSender<HTTPResponseConcludingAsyncWriter>
    ) async throws {
        // 1. Eagerly collect the full request body
        let collectedBody = try await requestBodyAndTrailers.consumeAndConclude { reader in
            var reader: HTTPRequestConcludingAsyncReader.RequestBodyAsyncReader? = reader
            var collected = ByteBuffer()
            var shouldContinue = true
            while shouldContinue {
                try await reader!.read(maximumCount: nil) { span in
                    if span.isEmpty {
                        shouldContinue = false
                    } else {
                        collected.writeBytes(span.withUnsafeBufferPointer { Array($0) })
                    }
                }
            }
            return collected
        }
        let bodyBuffer: ByteBuffer = collectedBody.0
        // collectedBody.1 contains trailers if any

        // 2. Build Vapor request
        let peerCerts = try? await NIOHTTPServer.connectionContext.peerCertificateChain

        // HTTPRequest.path is the raw request target, already percent-encoded,
        // and includes the query string (e.g. "/foo%20bar?baz=1").
        // Pass it as the sole argument so URI.init takes the path-only parsing
        // branch, which preserves percent encoding rather than double-encoding.
        let rawPath = request.path ?? "/"

        let vaporRequest = Request(
            application: self.application,
            method: request.method,
            url: URI(path: rawPath),
            version: .init(major: 1, minor: 1),
            headersNoUpdate: request.headerFields,
            collectedBody: bodyBuffer.readableBytes > 0 ? bodyBuffer : nil,
            remoteAddress: nil,
            peerCertificateChain: peerCerts,
            logger: self.application.logger,
            byteBufferAllocator: self.application.byteBufferAllocator
        )

        // 3. Run responder chain
        let vaporResponse = try await responder.respond(to: vaporRequest)
        let httpResponse = HTTPResponse(
            status: vaporResponse.status,
            headerFields: vaporResponse.headers
        )

        // 4. Send response head and write body
        let responseWriter = try await responseSender.send(httpResponse)
        try await responseWriter.produceAndConclude { writer in
            var writer = writer
            if let buffer = vaporResponse.body.buffer {
                let bytes = Array(buffer.readableBytesView)
                var offset = 0
                while offset < bytes.count {
                    try await writer.write { (outputSpan: inout OutputSpan<UInt8>) in
                        let remaining = bytes.count - offset
                        let chunkSize = min(remaining, outputSpan.capacity)
                        for i in 0..<chunkSize {
                            outputSpan.append(bytes[offset + i])
                        }
                        offset += chunkSize
                    }
                }
            }
            // TODO: Handle streaming response bodies
            return ((), nil)
        }
    }
}
