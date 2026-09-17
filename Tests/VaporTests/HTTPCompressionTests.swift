import RoutingKit
@testable import Vapor
import VaporTesting
import HTTPTypes
import AsyncHTTPClient
import NIOHTTP1
import NIOHTTPCompression
import NIOSSL
import Foundation
import Testing

@Suite("HTTP Compression Tests", .timeLimit(.minutes(1)))
struct HTTPCompressionTests {
    private static let payload = String(repeating: "Hello, compressed world! ", count: 128)
    private static let gzip = Data(base64Encoded: "H4sIAAAAAAAC/+3JsREAIAgAsVWwdxD2EDo8PChc3yUsP23UI3LKyn3Ku93kZoUNUYIgCIIgCIIgiL/xAAxnObaADAAA")!
    private static let deflate = Data(base64Encoded: "eJztybERACAIALFVsHcQ9hA6PDwoXN8lLD9t1CNyysp9yrvd5GaFDVGCIAiCIAiCIIi/8QAKUX89")!

    private func withServer(
        http2: Bool = false,
        configure: (Application) throws -> Void,
        test: (any TestClient) async throws -> Void
    ) async throws {
        try await withApp { app in
            var clientConfiguration = HTTPClient.Configuration()
            clientConfiguration.decompression = .enabled(limit: .none)
            var options = LiveClientOptions(configuration: clientConfiguration)
            if http2 {
                let credentials = try TestCredentials.localhost()
                app.serverConfiguration.tlsConfiguration = .pemFile(
                    certificateChainPath: credentials.certificatePath,
                    privateKeyPath: credentials.privateKeyPath)
                app.serverConfiguration.httpVersions = [.http2(config: .defaults)]
                var tls = NIOSSL.TLSConfiguration.makeClientConfiguration()
                tls.trustRoots = .certificates([credentials.nioCertificate])
                options.tls = tls
            }
            try configure(app)
            try await app.testing(.running, options: .live(clientOptions: options), test)
        }
    }

    // Replaces the HTTP/1 and HTTP/2 request tests, with both supported encodings and policies.
    @Test("Request decompression over HTTP/1 and HTTP/2", arguments: [false, true], [false, true])
    func requestDecompression(http2: Bool, enabled: Bool) async throws {
        try await self.withServer(http2: http2) { app in
            app.serverConfiguration.requestDecompression = enabled ? .enabled(limit: .size(Self.payload.utf8.count)) : .disabled
            app.post("echo") { request async throws in
                let body = try await request.body.collect()
                var headers = HTTPFields()
                headers[HTTPField.Name("echo-encoding")!] = request.headers[.contentEncoding]
                headers[HTTPField.Name("echo-length")!] = request.headers[.contentLength]
                return Response(headers: headers, body: .init(data: body ?? Data()))
            }
        } test: { client in
            for (encoding, data) in [("gzip", Self.gzip), ("deflate", Self.deflate), ("br", Self.gzip), (nil, Self.gzip)] as [(String?, Data)] {
                let response = try await client.post("/echo") {
                    $0.headers[.contentEncoding] = encoding
                    $0.body = .init(data: data)
                }
                let decoded = enabled && (encoding == "gzip" || encoding == "deflate")
                #expect(response.status == .ok)
                try #expect(await response.body.data() == (decoded ? Data(Self.payload.utf8) : data))
                #expect(response.headers[HTTPField.Name("echo-encoding")!] == (decoded ? nil : encoding))
                #expect(response.headers[HTTPField.Name("echo-length")!] == (decoded ? nil : String(data.count)))
            }
        }
    }

    // Replaces the HTTP/1 and HTTP/2 response tests. Automatic client decoding independently
    // validates the bytes produced by Vapor; a second client checks the actual representation.
    @Test("Response compression over HTTP/1 and HTTP/2", arguments: [false, true], [false, true])
    func responseCompression(http2: Bool, enabled: Bool) async throws {
        try await self.withServer(http2: http2) { app in
            app.serverConfiguration.responseCompression = enabled ? .enabled : .disabled
            app.get("body") { _ in Self.payload }
        } test: { client in
            for encoding in ["gzip", "deflate", "identity"] {
                let response = try await client.get("/body") { $0.headers[.acceptEncoding] = encoding }
                try #expect(await response.body.requireString() == Self.payload)
            }
        }
    }

    @Test("Large request decompression", .bug("https://github.com/vapor/vapor/issues/2766"))
    func largeRequestDecompression() async throws {
        let data = Data(base64Encoded: "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")!
        try await self.withServer { app in
            app.serverConfiguration.requestDecompression = .enabled(limit: .size(200_000))
            app.on(.post, "json", maxBodySize: "200kb") { request async throws in
                struct Nothing: Codable {}
                _ = try await request.content.decode(Nothing.self)
                return HTTPResponse.Status.ok
            }
        } test: { client in
            let response = try await client.post("/json") {
                $0.headers[.contentEncoding] = "gzip"
                $0.headers[.contentType] = "application/json"
                $0.body = .init(data: data)
            }
            #expect(response.status == .ok)
        }
    }

    @Test("Decompression limit includes streamed output", arguments: [false, true])
    func decompressionLimit(streamed: Bool) async throws {
        let small = Data(base64Encoded: "H4sIAAAAAAAAE/NIzcnJ11Eozy/KSVEEAObG5usNAAAA")!
        let big = Data(base64Encoded: "H4sIAAAAAAAAE/NIzcnJ11HILU3OgBBJmenpqUUK5flFOSkKJRmJeQpJqWn5RamKAICcGhUqAAAA")!
        try await self.withServer { app in
            app.serverConfiguration.requestDecompression = .enabled(limit: .size(13))
            app.post("echo") { request async throws -> String in
                if streamed {
                    var result = Data()
                    try await request.body.forEachChunk { result.append($0.withUnsafeBufferPointer { unsafe Data(buffer: $0) }) }
                    return String(decoding: result, as: UTF8.self)
                }
                return try await request.body.string() ?? ""
            }
        } test: { client in
            let accepted = try await client.post("/echo") {
                $0.headers[.contentEncoding] = "gzip"
                $0.body = .init(data: small)
            }
            try #expect(await accepted.body.requireString() == "Hello, world!")
            let rejected = try await client.post("/echo") {
                $0.headers[.contentEncoding] = "gzip"
                $0.body = .init(data: big)
            }
            // Middleware can now return a useful response instead of closing the connection.
            #expect(rejected.status == .contentTooLarge)
        }
    }

    @Test("Chunked compressed input and streamed compressed output", arguments: [false, true])
    func streaming(http2: Bool) async throws {
        try await self.withServer(http2: http2) { app in
            app.serverConfiguration.requestDecompression = .enabled(limit: .size(Self.payload.utf8.count))
            app.serverConfiguration.responseCompression = .enabled
            app.post("echo") { request async throws in
                // Finish the upload before returning the response head: the live test client's
                // request producer is scoped to receiving that head, rather than the response body.
                var chunks: [Data] = []
                try await request.body.forEachChunk { bytes in
                    chunks.append(bytes.withUnsafeBufferPointer { unsafe Data(buffer: $0) })
                }
                let decodedChunks = chunks
                return Response(body: .init(stream: { writer in
                    for chunk in decodedChunks { try await writer.write(chunk.span) }
                }))
            }
        } test: { client in
            for encoding in ["gzip", "deflate"] {
                let response = try await client.post("/echo") {
                    $0.headers[.contentEncoding] = "gzip"
                    $0.headers[.acceptEncoding] = encoding
                    $0.body = .init(stream: { writer in
                        for byte in Self.gzip { try await writer.write([byte]) }
                    })
                }
                #expect(response.status == .ok)
                try #expect(await response.body.requireString() == Self.payload)
            }
        }
    }

    @Test("Route collection limit applies to decompressed bytes")
    func routeLimit() async throws {
        try await self.withServer { app in
            app.serverConfiguration.requestDecompression = .enabled(limit: .none)
            app.on(.post, "body", maxBodySize: "1kb") { request async throws in
                try await request.body.string() ?? ""
            }
        } test: { client in
            let response = try await client.post("/body") {
                $0.headers[.contentEncoding] = "gzip"
                $0.body = .init(data: Self.gzip)
            }
            #expect(response.status == .contentTooLarge)
        }
    }

    @Test("Decompression ratio policy", arguments: [1, 100])
    func ratioLimit(ratio: Int) async throws {
        try await self.withServer { app in
            app.serverConfiguration.requestDecompression = .enabled(limit: .ratio(ratio))
            app.post("body") { request async throws in try await request.body.string() ?? "" }
        } test: { client in
            let response = try await client.post("/body") {
                $0.headers[.contentEncoding] = "gzip"
                $0.body = .init(data: Self.gzip)
            }
            #expect(response.status == (ratio == 1 ? .contentTooLarge : .ok))
        }
    }

    @Test("Response metadata and bodies excluded from compression")
    func responseMetadata() async throws {
        try await self.withServer { app in
            app.serverConfiguration.responseCompression = .enabled
            app.get("metadata") { _ in
                Response(headers: [.vary: "Origin", .eTag: "\"identity\""], body: .init(string: Self.payload))
            }
            app.get("encoded") { _ in
                Response(headers: [.contentEncoding: "gzip"], body: .init(data: Self.gzip))
            }
            app.get("range") { _ in
                Response(status: .partialContent, headers: [.contentRange: "bytes 0-4/10"], body: "hello")
            }
            app.get("empty") { _ in Response() }
            app.get("head") { _ in
                Response(body: .init(stream: { _ in Issue.record("HEAD must not invoke the body") }))
            }
            app.get("error") { _ -> Response in throw Abort(.badRequest, reason: "Example error") }
        } test: { client in
            var raw = HTTPClient.Configuration()
            raw.decompression = .disabled
            try await client.withOptions(.init(configuration: raw)) { client in
                let response = try await client.get("/metadata") { $0.headers[.acceptEncoding] = "gzip" }
                #expect(response.headers[.contentEncoding] == "gzip")
                #expect(response.headers[.eTag] == "W/\"identity\"")
                #expect(response.headers[.vary] == "Origin, Accept-Encoding")
                let identity = try await client.get("/metadata") { $0.headers[.acceptEncoding] = "identity" }
                #expect(identity.headers[.vary] == "Origin, Accept-Encoding")
                #expect(identity.headers[.eTag] == "\"identity\"")
                let encoded = try await client.get("/encoded") { $0.headers[.acceptEncoding] = "gzip" }
                try #expect(await encoded.body.data() == Self.gzip)
                for path in ["/range", "/empty"] {
                    let response = try await client.get(URI(string: path)) { $0.headers[.acceptEncoding] = "gzip" }
                    #expect(response.headers[.contentEncoding] == nil)
                }
                let head = try await client.send(.init(method: .head, url: "/head", headers: [.acceptEncoding: "gzip"]))
                #expect(head.status == .ok)
                let error = try await client.get("/error") { $0.headers[.acceptEncoding] = "gzip" }
                #expect(error.status == .badRequest)
                #expect(error.headers[.contentEncoding] == "gzip")
            }
        }
    }

    @Test("Compressed stream preserves producer failures and length checks", arguments: [false, true])
    func failedResponseStream(wrongLength: Bool) async throws {
        try await self.withServer { app in
            app.serverConfiguration.responseCompression = .enabled
            app.get("stream") { _ in
                Response(body: try .init(stream: { writer in
                    try await writer.write("partial")
                    if !wrongLength { throw Abort(.internalServerError) }
                }, count: wrongLength ? 100 : nil))
            }
        } test: { client in
            await #expect(throws: (any Error).self) {
                let response = try await client.get("/stream") { $0.headers[.acceptEncoding] = "gzip" }
                _ = try await response.body.data()
            }
        }
    }

    @Test("Invalid compressed bodies return bad request")
    func invalidRequestBodies() async throws {
        try await self.withServer { app in
            app.serverConfiguration.requestDecompression = .enabled(limit: .none)
            app.post("body") { request async throws in try await request.body.string() ?? "" }
        } test: { client in
            for data in [Data(Self.gzip.dropLast()), Self.gzip + Data([0]), Data("invalid".utf8)] {
                let response = try await client.post("/body") {
                    $0.headers[.contentEncoding] = "gzip"
                    $0.body = .init(data: data)
                }
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test("Accept-Encoding preferences", arguments: [
        ("gzip", "gzip"), ("deflate", "deflate"), ("GZip", "gzip"),
        ("deflate;q=0.8, gzip;q=0.5", "deflate"), ("gzip;q=0, *;q=1", "deflate"),
        ("*;q=0", nil), ("gzip;q=0, deflate;q=0", nil), ("br", nil),
        ("gzip;q=garbage", nil), ("gzip;q", nil), ("gzip;q=NaN", nil),
        ("gzip;q=2", nil), ("gzip;q=0.5, identity;q=1", nil), ("", nil),
    ] as [(String, String?)])
    func negotiation(header: String, expected: String?) {
        #expect(HTTPCompressionMiddleware.negotiate(header)?.rawValue == expected)
    }
}
