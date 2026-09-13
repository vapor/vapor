import Vapor
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

/// A ``Vapor/Client`` backed by AsyncHTTPClient, for the live test client.
///
/// This is a copy of Vapor's own `VaporHTTPClient`, which only exists when the package's
/// `HTTPClient` trait is enabled. VaporTesting links AsyncHTTPClient unconditionally - a live test
/// needs a real client whatever the app under test chose - so it cannot rely on Vapor's, and Vapor
/// cannot depend on VaporTesting to share one. Keep the two in step.
struct AHCClient: Client {
    let http: HTTPClient
    let contentConfiguration: ContentConfiguration

    func send(_ clientRequest: ClientRequest) async throws -> ClientResponse {
        let urlString = clientRequest.url.string
        guard let url = URL(string: urlString) else {
            Logger.current.debug("Invalid URL", metadata: ["urlString": "\(urlString)"])
            throw Abort(.internalServerError, reason: "\(urlString) is an invalid URL")
        }
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .init(clientRequest.method)
        request.headers = .init(clientRequest.headers)
        let (ahcBody, producer) = ahcRequestBody(clientRequest.body)
        request.body = ahcBody
        // The body's closure runs alongside the request: AHC pulls from the handoff as the connection
        // accepts bytes. Cancelling on the way out unparks it if the request failed part-way.
        let pump = producer.map { pumpRequestBody(clientRequest.body, into: $0) }
        defer { pump?.cancel() }
        let response: HTTPClientResponse
        do {
            response = try await self.http.execute(
                request,
                deadline: .now() + TimeAmount(clientRequest.timeout),
                logger: Logger.current)
        } catch {
            producer?.finish(throwing: error)
            throw error
        }
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
                    try await writer.write(chunk.readableBytesUInt8Span)
                }
            }, count: declaredLength),
            maxBodySize: clientRequest.maxResponseBodySize,
            contentConfiguration: self.contentConfiguration
        )
    }
}

/// Adapts a Vapor client request body into AsyncHTTPClient's, and returns the producer that has to
/// run alongside the request for a streaming one.
///
/// A buffered body goes over as `.bytes`, with its length known up front. A streaming body is joined
/// to AHC through a ``ChunkHandoff``: AHC pulls chunks from the sequence while the body's own closure
/// pushes them in, each `write` returning only once the transport has taken the bytes.
private func ahcRequestBody(
    _ body: Response.Body
) -> (body: HTTPClientRequest.Body?, producer: ChunkHandoff?) {
    // No body at all, as distinct from a body that happens to be empty. This is what a `nil`
    // `ByteBuffer` used to mean, and AHC frames it the same way — `Content-Length: 0` on a method
    // that expects a body — rather than as a zero-length chunked upload.
    if body.count == 0, !body.isUnconsumedStream {
        return (nil, nil)
    }
    // An already-collected or buffered body: hand the bytes over whole.
    if let data = body.data {
        return (.bytes(data, length: .known(Int64(data.count))), nil)
    }
    let handoff = ChunkHandoff()
    let length: HTTPClientRequest.Body.Length = body.count.map { .known(Int64($0)) } ?? .unknown
    return (.stream(ChunkHandoffSequence(handoff: handoff), length: length), handoff)
}

/// Runs a streaming body's closure, feeding each chunk into the handoff, and ends the handoff either
/// way so the consumer is never left waiting.
private func pumpRequestBody(_ body: Response.Body, into handoff: ChunkHandoff) -> Task<Void, Never> {
    Task {
        do {
            var chunk = ByteBuffer()
            try await body.withStreamingBytes { span in
                // The span is only valid for this call, so the bytes are copied into a buffer the
                // handoff can own. The buffer is reused across chunks.
                chunk.clear()
                let count = span.withUnsafeBufferPointer { unsafe chunk.writeBytes($0) }
                guard count == span.count else {
                    throw Abort(.internalServerError)
                }
                try await handoff.send(chunk)
            }
            handoff.finish()
        } catch {
            handoff.finish(throwing: error)
        }
    }
}
