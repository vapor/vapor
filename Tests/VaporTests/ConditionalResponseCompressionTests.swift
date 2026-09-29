#if Compression
import RoutingKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Vapor
import AsyncHTTPClient
import Testing
import VaporTesting
import HTTPTypes

@Suite("Response Compression Media Type Policies")
struct ConditionalResponseCompressionTests {
    // Each policy is configured before startup; server configuration is now frozen while running.
    func assertCompression(
        _ cases: [(ServerConfiguration.ResponseCompressionConfiguration, Bool)],
        configure: (Application) throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        for (configuration, compressed) in cases {
            try await withApp { app in
                app.serverConfiguration.responseCompression = configuration
                try configure(app)
                app.middleware.use(app.makeResponseCompressionMiddleware(), at: .beginning)
                try await app.testing(.running) { client in
                    let response = try await client.get("/resource") {
                        $0.headers[.acceptEncoding] = "gzip"
                    }
                    // The live client strips encoding/framing headers when it decodes. Use a raw
                    // client for wire assertions, and the regular client for an independent decode.
                    try #expect(await response.body.requireString() == compressiblePayload, sourceLocation: sourceLocation)
                    var raw = HTTPClient.Configuration()
                    raw.decompression = .disabled
                    try await client.withOptions(.init(configuration: raw)) { client in
                        let response = try await client.get("/resource") { $0.headers[.acceptEncoding] = "gzip" }
                        #expect(response.headers[.contentEncoding] == (compressed ? "gzip" : nil), sourceLocation: sourceLocation)
                        let bytes = try await response.body.data()
                        #expect((bytes?.count != compressiblePayload.utf8.count) == compressed, sourceLocation: sourceLocation)
                        #expect(response.headers[.contentLength] == bytes.map { String($0.count) }, sourceLocation: sourceLocation)
                    }
                }
            }
        }
    }

    @Test("Test Auto Detected Type")
    func testAutoDetectedType() async throws {
        try await assertCompression([
            (ServerConfiguration().responseCompression, true),
            (.init(mediaTypes: .only(.none)), false),
            (.init(), true),
            (.init(mediaTypes: .excluding(.incompressible)), true),
            (.init(mediaTypes: .only(.compressible)), true),
            (.init(mediaTypes: .only(.all)), true),
            (.init(mediaTypes: .excluding(.none)), true),
            (.init(mediaTypes: .excluding(.all)), false),
        ]) { app in
            app.get("resource") { _ in compressiblePayload }
        }
    }

    @Test("Test Unknown Type")
    func testUnknownType() async throws {
        try await assertCompression([
            (ServerConfiguration().responseCompression, false),
            (.init(mediaTypes: .only(.none)), false),
            (.init(), false),
            (.init(mediaTypes: .excluding(.incompressible)), true),
            (.init(mediaTypes: .only(.compressible)), false),
            (.init(mediaTypes: .only(.all)), true),
            (.init(mediaTypes: .excluding(.none)), true),
            (.init(mediaTypes: .excluding(.all)), false),
        ]) { app in
            app.get("resource") { _ in
                var headers = HTTPFields()
                headers.contentType = unknownType
                /// Not explicitly marked as compressible or not.
                return Response(status: .ok, headers: headers, body: .init(string: compressiblePayload))
            }
        }
    }

    @Test("Test Image")
    func testImage() async throws {
        try await assertCompression([
            (ServerConfiguration().responseCompression, false),
            (.init(mediaTypes: .only(.none)), false),
            (.init(), false),
            (.init(mediaTypes: .excluding(.incompressible)), false),
            (.init(mediaTypes: .only(.compressible)), false),
            (.init(mediaTypes: .only(.all)), true),
            (.init(mediaTypes: .excluding(.none)), true),
            (.init(mediaTypes: .excluding(.all)), false),
        ]) { app in
            app.get("resource") { _ in
                var headers = HTTPFields()
                headers.contentType = .png
                /// PNGs are explicitly called out as incompressible.
                return Response(status: .ok, headers: headers, body: .init(string: compressiblePayload))
            }
        }
    }

    @Test("Test Video")
    func testVideo() async throws {
        try await assertCompression([
            (ServerConfiguration().responseCompression, false),
            (.init(mediaTypes: .only(.none)), false),
            (.init(), false),
            (.init(mediaTypes: .excluding(.incompressible)), false),
            (.init(mediaTypes: .only(.compressible)), false),
            (.init(mediaTypes: .only(.all)), true),
            (.init(mediaTypes: .excluding(.none)), true),
            (.init(mediaTypes: .excluding(.all)), false),
        ]) { app in
            app.get("resource") { _ in
                var headers = HTTPFields()
                headers.contentType = .mpeg
                /// Videos are explicitly called out as incompressible, but as a class.
                return Response(status: .ok, headers: headers, body: .init(string: compressiblePayload))
            }
        }
    }

    @Test("Test Text")
    func testText() async throws {
        try await assertCompression([
            (ServerConfiguration().responseCompression, true),
            (.init(mediaTypes: .only(.none)), false),
            (.init(), true),
            (.init(mediaTypes: .excluding(.incompressible)), true),
            (.init(mediaTypes: .only(.compressible)), true),
            (.init(mediaTypes: .only(.all)), true),
            (.init(mediaTypes: .excluding(.none)), true),
            (.init(mediaTypes: .excluding(.all)), false),
        ]) { app in
            app.get("resource") { _ in
                var headers = HTTPFields()
                headers.contentType = .plainText
                /// Text types are explicitly called out as compressible, but as a class.
                return Response(status: .ok, headers: headers, body: .init(string: compressiblePayload))
            }
        }
    }

    @Test("Test Missing Content Type")
    func testMissingContentType() async throws {
        try await assertCompression([
            (ServerConfiguration().responseCompression, false),
            (.init(mediaTypes: .only(.none)), false),
            (.init(), false),
            (.init(mediaTypes: .excluding(.incompressible)), true),
            (.init(mediaTypes: .only(.compressible)), false),
            (.init(mediaTypes: .only(.all)), false),
            (.init(mediaTypes: .excluding(.none)), true),
            (.init(mediaTypes: .excluding(.all)), true),
        ]) { app in
            app.get("resource") { _ in
                Response(status: .ok, body: .init(string: compressiblePayload))
            }
        }
    }
}

private let compressiblePayload =
    #"{"compressed": ["key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value"]}"#

private let unknownType = HTTPMediaType(type: "vapor-test", subType: "unknown")

#endif
