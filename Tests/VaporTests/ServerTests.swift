import NIOHTTP1
import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers
import HTTPTypes
import NIOSSL
import Atomics
import Testing
import VaporTesting
import NIOHTTPTypesHTTP1

@Suite("Server Tests", .disabled())
struct ServerTests {
    @Test("Test Port Override")
    func testPortOverride() async throws {
        let env = Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--port", "8123"]
        )
        
        let app = try await Application(env)
        
        app.get("foo") { req in
            return "bar"
        }
        try await app.startup()

        let res = try await app.client.get("http://127.0.0.1:8123/foo")
        #expect(res.body?.string == "bar")

        try await app.shutdown()
    }
    
    @Test("Test Socke Path Override")
    func testSocketPathOverride() async throws {
        let socketPath = "/tmp/\(UUID().uuidString).vapor.socket"
        
        let env = Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--unix-socket", socketPath]
        )
        
        let app = try await Application(env)

        app.get("foo") { _ in "bar" }
        try await app.startup()

        let res = try await app.client.get(.init(scheme: .httpUnixDomainSocket, host: socketPath, path: "/foo")) { $0.timeout = .milliseconds(500) }
        #expect(res.body?.string == "bar")

        // no server should be bound to the port despite one being set on the configuration.
        await #expect(throws: IOError.self) {
            try await app.client.get("http://127.0.0.1:8080/foo") { $0.timeout = .milliseconds(500) }
        }

        try await app.shutdown()
    }

    @Test("Test Incompatible Startup Options")
    func testIncompatibleStartupOptions() async throws {
        func checkForError(_ app: Application) async throws {
            await #expect(throws: ServeCommand.Error.incompatibleFlags) {
                try await app.startup()
            }
            try await app.shutdown()
        }
        
        var app = try await Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--port", "8123", "--unix-socket", "/path/to/socket"]
        ))
        try await checkForError(app)

        app = try await Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--hostname", "localhost", "--unix-socket", "/path/to/socket"]
        ))
        try await checkForError(app)

        app = try await Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--unix-socket", "/path/to/socket"]
        ))
        try await checkForError(app)

        app = try await Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--hostname", "1.2.3.4"]
        ))
        try await checkForError(app)

        app = try await Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--port", "8081"]
        ))
        try await checkForError(app)

        app = try await Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--port", "8081", "--unix-socket", "/path/to/socket"]
        ))
        try await checkForError(app)

        app = try await Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--hostname", "1.2.3.4", "--unix-socket", "/path/to/socket"]
        ))
        try await checkForError(app)

        app = try await Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--hostname", "1.2.3.4", "--port", "8081", "--unix-socket", "/path/to/socket"]
        ))
        try await checkForError(app)

        app = try await Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--hostname", "1.2.3.4", "--port", "8081", "--unix-socket", "/path/to/socket"]
        ))
        try await checkForError(app)
    }

    @Test("Test HTTP Large Decompression", .bug("http://github.com/vapor/vapor/issues/2766"))
    func testHTTPLargeDecompression() async throws {
        let payload_2766 = "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"
        
        let jsonPayload = ByteBuffer(base64String: payload_2766)! // Payload from #2766

        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            // Max out at the smaller payload (.size is of compressed data)
            app.http.server.configuration.requestDecompression = .enabled(limit: .size(200_000))
            app.post("gzip") { $0.body.string ?? "" }

            try await app.server.start()

            let port = try #require(app.http.server.shared.localAddress?.port)

            // Small payload should just barely get through.
            let res = try await app.client.post("http://localhost:\(port)/gzip") { req in
                req.headers[.contentEncoding] = "gzip"
                req.headers[.contentType] = "application/json"
                req.body = jsonPayload
            }

            if let body = res.body {
                // Validate that we received a valid JSON object
                struct Nothing: Codable {}
                #expect(throws: Never.self) {
                    try JSONDecoder().decode(Nothing.self, from: body)
                }
            } else {
                Issue.record("Missing response.body")
            }

            try await app.server.shutdown()
        }
    }

    @Test("Test Configure HTTP Decompression Limit")
    func testConfigureHTTPDecompressionLimit() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            let smallOrigString = "Hello, world!"
            let smallBody = ByteBuffer(base64String: "H4sIAAAAAAAAE/NIzcnJ11Eozy/KSVEEAObG5usNAAAA")! // "Hello, world!"
            let bigBody = ByteBuffer(base64String: "H4sIAAAAAAAAE/NIzcnJ11HILU3OgBBJmenpqUUK5flFOSkKJRmJeQpJqWn5RamKAICcGhUqAAAA")! // "Hello, much much bigger world than before!"

            // Max out at the smaller payload (.size is of uncompressed data)
            app.http.server.configuration.requestDecompression = .enabled(
                limit: .size(smallOrigString.utf8.count)
            )
            app.post("gzip") { $0.body.string ?? "" }

            try await app.server.start()

            let port = try #require(app.http.server.shared.localAddress?.port)
            // Small payload should just barely get through.
            let res = try await app.client.post("http://localhost:\(port)/gzip") { req in
                req.headers[.contentEncoding] = "gzip"
                req.body = smallBody
            }
            #expect(res.body?.string == smallOrigString)

            // Big payload should be hard-rejected. We can't test for the raw NIOHTTPDecompression.DecompressionError.limit error here because
            // protocol decoding errors are only ever logged and can't be directly caught.
            await #expect(throws: HTTPClientError.remoteConnectionClosed) {
                _ = try await app.client.post("http://localhost:\(port)/gzip") { req in
                    req.headers[.contentEncoding] = "gzip"
                    req.body = bigBody
                }
            }

            try await app.server.shutdown()
        }
    }

    @Test("Test HTTP1 Request Decompression")
    func testHTTP1RequestDecompression() async throws {
        let compressiblePayload = #"{"compressed": ["key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value"]}"#
        /// To regenerate, copy the above and run `% pbpaste | gzip | base64`. To verify, run `% pbpaste | base64 -d | gzip -d` instead.
        let compressedPayload = ByteBuffer(base64String: "H4sIANRAImYAA6tWSs7PLShKLS5OTVGyUohWyk6tBNJKZYk5palKOgqj/FH+KH+UP8of5RPmx9YCAMfjVAhQBgAA")!

        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            app.http.server.configuration.supportVersions = [.one]
            app.http.server.configuration.requestDecompression = .disabled

            /// Make sure the client doesn't keep the server open by re-using the connection.
            app.http.client.configuration.maximumUsesPerConnection = 1

            struct TestResponse: Content {
                var content: ByteBuffer?
                var contentLength: Int
            }

            app.on(.post, "compressed", body: .collect(maxSize: "1mb")) { request async throws in
                let contentLength = request.headers[.contentLength].flatMap { Int($0) }
                let contents = try await request.body.collect().get()
                return TestResponse(
                    content: contents,
                    contentLength: contentLength ?? 0
                )
            }

            try await app.server.start()
            let port = try #require(app.http.server.shared.localAddress?.port)

            let unsupportedNoncompressedResponse = try await app.client.post("http://localhost:\(port)/compressed") { request in
                request.body = compressedPayload
            }

            if let body = unsupportedNoncompressedResponse.body {
                let decodedResponse = try JSONDecoder().decode(TestResponse.self, from: body)
                #expect(decodedResponse.content == compressedPayload)
                #expect(decodedResponse.contentLength == compressedPayload.readableBytes)
            } else {
                Issue.record("Missing unsupportedNoncompressedResponse.body")
            }

            // TODO: The server should probably reject this?
            let unsupportedCompressedResponse = try await app.client.post("http://localhost:\(port)/compressed") { request in
                request.headers[.contentEncoding] = "gzip"
                request.body = compressedPayload
            }

            if let body = unsupportedCompressedResponse.body {
                let decodedResponse = try JSONDecoder().decode(TestResponse.self, from: body)
                #expect(decodedResponse.content == compressedPayload)
                #expect(decodedResponse.contentLength == compressedPayload.readableBytes)
            } else {
                Issue.record("Missing unsupportedCompressedResponse.body")
            }

            app.http.server.configuration.requestDecompression = .enabled(limit: .size(compressiblePayload.utf8.count))

            let supportedUncompressedResponse = try await app.client.post("http://localhost:\(port)/compressed") { request in
                request.body = compressedPayload
            }

            if let body = supportedUncompressedResponse.body {
                let decodedResponse = try JSONDecoder().decode(TestResponse.self, from: body)
                #expect(decodedResponse.content == compressedPayload)
                #expect(decodedResponse.contentLength == compressedPayload.readableBytes)
            } else {
                Issue.record("Missing supportedUncompressedResponse.body")
            }

            let supportedCompressedResponse = try await app.client.post("http://localhost:\(port)/compressed") { request in
                request.headers[.contentEncoding] = "gzip"
                request.body = compressedPayload
            }

            if let body = supportedCompressedResponse.body {
                let decodedResponse = try JSONDecoder().decode(TestResponse.self, from: body)
                #expect(decodedResponse.content == ByteBuffer(string: compressiblePayload))
                #expect(decodedResponse.contentLength == compressedPayload.readableBytes)
            } else {
                Issue.record("Missing supportedCompressedResponse.body")
            }

            try await app.server.shutdown()
        }
    }

    @Test("Test HTTP2 Request Decompression")
    func testHTTP2RequestDecompression() async throws {
        try await withApp { app in
            guard let clientCertPath = Bundle.module.url(forResource: "expired", withExtension: "crt"),
                  let clientKeyPath = Bundle.module.url(forResource: "expired", withExtension: "key") else {
                Issue.record("Cannot load expired cert and associated key")
                return
            }

            let cert = try NIOSSLCertificate(file: clientCertPath.path, format: .pem)
            let key = try NIOSSLPrivateKey(file: clientKeyPath.path, format: .pem)

            let compressiblePayload = #"{"compressed": ["key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value"]}"#
            /// To regenerate, copy the above and run `% pbpaste | gzip | base64`. To verify, run `% pbpaste | base64 -d | gzip -d` instead.
            let compressedPayload = ByteBuffer(base64String: "H4sIANRAImYAA6tWSs7PLShKLS5OTVGyUohWyk6tBNJKZYk5palKOgqj/FH+KH+UP8of5RPmx9YCAMfjVAhQBgAA")!

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            var serverConfig = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(cert)], privateKey: .privateKey(key))
            serverConfig.certificateVerification = .noHostnameVerification

            app.http.server.configuration.tlsConfiguration = serverConfig
            app.http.server.configuration.customCertificateVerifyCallback = { @Sendable peerCerts, successPromise in
                /// This lies and accepts the above cert, which has actually expired.
                #expect(peerCerts == [cert])
                successPromise.succeed(.certificateVerified)
            }
            app.http.server.configuration.supportVersions = [.two]
            app.http.server.configuration.requestDecompression = .disabled

            /// We need to disable verification on the client, because the cert we're using has expired
            var clientConfig = TLSConfiguration.makeClientConfiguration()
            clientConfig.certificateVerification = .none
            clientConfig.certificateChain = [.certificate(cert)]
            clientConfig.privateKey = .privateKey(key)
            app.http.client.configuration.tlsConfiguration = clientConfig

            /// Make sure the client doesn't keep the server open by re-using the connection.
            app.http.client.configuration.maximumUsesPerConnection = 1

            struct TestResponse: Content {
                var content: ByteBuffer?
                var contentLength: Int
            }

            app.post("compressed") { request async throws in
                let contentLength = request.headers[.contentLength]
                let contents = try await request.body.collect().get()
                return TestResponse(
                    content: contents,
                    contentLength: contentLength.flatMap { Int($0) } ?? 0
                )
            }

            try await app.server.start()
            let port = try #require(app.http.server.shared.localAddress?.port)

            let unsupportedNoncompressedResponse = try await app.client.post("https://localhost:\(port)/compressed") { request in
                request.body = compressedPayload
            }

            if let body = unsupportedNoncompressedResponse.body {
                let decodedResponse = try JSONDecoder().decode(TestResponse.self, from: body)
                #expect(decodedResponse.content == compressedPayload)
                #expect(decodedResponse.contentLength == compressedPayload.readableBytes)
            } else {
                Issue.record("Missing unsupportedNoncompressedResponse.body")
            }

            // TODO: The server should probably reject this?
            let unsupportedCompressedResponse = try await app.client.post("https://localhost:\(port)/compressed") { request in
                request.headers[.contentEncoding] = "gzip"
                request.body = compressedPayload
            }

            if let body = unsupportedCompressedResponse.body {
                let decodedResponse = try JSONDecoder().decode(TestResponse.self, from: body)
                #expect(decodedResponse.content == compressedPayload)
                #expect(decodedResponse.contentLength == compressedPayload.readableBytes)
            } else {
                Issue.record("Missing unsupportedCompressedResponse.body")
            }

            app.http.server.configuration.requestDecompression = .enabled(limit: .size(compressiblePayload.utf8.count))

            let supportedUncompressedResponse = try await app.client.post("https://localhost:\(port)/compressed") { request in
                request.body = compressedPayload
            }

            if let body = supportedUncompressedResponse.body {
                let decodedResponse = try JSONDecoder().decode(TestResponse.self, from: body)
                #expect(decodedResponse.content == compressedPayload)
                #expect(decodedResponse.contentLength == compressedPayload.readableBytes)
            } else {
                Issue.record("Missing supportedUncompressedResponse.body")
            }

            let supportedCompressedResponse = try await app.client.post("https://localhost:\(port)/compressed") { request in
                request.headers[.contentEncoding] = "gzip"
                request.body = compressedPayload
            }

            if let body = supportedCompressedResponse.body {
                let decodedResponse = try JSONDecoder().decode(TestResponse.self, from: body)
                #expect(decodedResponse.content == ByteBuffer(string: compressiblePayload))
                #expect(decodedResponse.contentLength == compressedPayload.readableBytes)
            } else {
                Issue.record("Missing supportedCompressedResponse.body")
            }

            try await app.server.shutdown()
        }
    }

    @Test("Test HTTP1 Response Decompression")
    func testHTTP1ResponseDecompression() async throws {
        try await withApp { app in
            let compressiblePayload = #"{"compressed": ["key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value"]}"#

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            app.http.server.configuration.supportVersions = [.one]
            app.http.server.configuration.responseCompression = .disabled

            /// Make sure the client doesn't keep the server open by re-using the connection.
            app.http.client.configuration.maximumUsesPerConnection = 1
            app.http.client.configuration.decompression = .enabled(limit: .none)

            app.get("compressed") { _ in compressiblePayload }

            try await app.server.start()
            let port = try #require(app.http.server.shared.localAddress?.port)

            let unsupportedNoncompressedResponse = try await app.client.get("http://localhost:\(port)/compressed") { request in
                request.headers[.acceptEncoding] = nil
            }
            #expect(unsupportedNoncompressedResponse.headers[.contentEncoding] != "gzip")
            #expect(unsupportedNoncompressedResponse.headers[.contentLength] == "\(compressiblePayload.count)")
            #expect(unsupportedNoncompressedResponse.body?.string == compressiblePayload)

            let unsupportedCompressedResponse = try await app.client.get("http://localhost:\(port)/compressed") { request in
                request.headers[.acceptEncoding] = "gzip"
            }
            #expect(unsupportedCompressedResponse.headers[.contentEncoding] != "gzip")
            #expect(unsupportedCompressedResponse.headers[.contentLength] == "\(compressiblePayload.count)")
            #expect(unsupportedCompressedResponse.body?.string == compressiblePayload)

            app.http.server.configuration.responseCompression = .enabled

            let supportedUncompressedResponse = try await app.client.get("http://localhost:\(port)/compressed") { request in
                request.headers[.acceptEncoding] = nil
            }
            #expect(supportedUncompressedResponse.headers[.contentEncoding] != "gzip")
            #expect(supportedUncompressedResponse.headers[.contentLength] != "\(compressiblePayload.count)")
            #expect(supportedUncompressedResponse.body?.string == compressiblePayload)

            let supportedCompressedResponse = try await app.client.get("http://localhost:\(port)/compressed") { request in
                request.headers[.acceptEncoding] = "gzip"
            }
            #expect(supportedCompressedResponse.headers[.contentEncoding] == "gzip")
            #expect(supportedCompressedResponse.headers[.contentLength] != "\(compressiblePayload.count)")
            #expect(supportedCompressedResponse.body?.string == compressiblePayload)

            try await app.server.shutdown()
        }
    }

    @Test("Test HTTP2 Response Decompression")
    func testHTTP2ResponseDecompression() async throws {
        try await withApp { app in
            guard let clientCertPath = Bundle.module.url(forResource: "expired", withExtension: "crt"),
                  let clientKeyPath = Bundle.module.url(forResource: "expired", withExtension: "key") else {
                Issue.record("Cannot load expired cert and associated key")
                return
            }

            let cert = try NIOSSLCertificate(file: clientCertPath.path, format: .pem)
            let key = try NIOSSLPrivateKey(file: clientKeyPath.path, format: .pem)

            let compressiblePayload = #"{"compressed": ["key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value"]}"#

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            var serverConfig = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(cert)], privateKey: .privateKey(key))
            serverConfig.certificateVerification = .noHostnameVerification

            app.http.server.configuration.tlsConfiguration = serverConfig
            app.http.server.configuration.customCertificateVerifyCallback = { @Sendable peerCerts, successPromise in
                /// This lies and accepts the above cert, which has actually expired.
                #expect(peerCerts == [cert])
                successPromise.succeed(.certificateVerified)
            }
            app.http.server.configuration.supportVersions = [.two]
            app.http.server.configuration.responseCompression = .disabled

            /// We need to disable verification on the client, because the cert we're using has expired
            var clientConfig = TLSConfiguration.makeClientConfiguration()
            clientConfig.certificateVerification = .none
            clientConfig.certificateChain = [.certificate(cert)]
            clientConfig.privateKey = .privateKey(key)
            app.http.client.configuration.tlsConfiguration = clientConfig

            app.http.client.configuration.decompression = .enabled(limit: .none)
            /// Make sure the client doesn't keep the server open by re-using the connection.
            app.http.client.configuration.maximumUsesPerConnection = 1

            app.get("compressed") { _ in compressiblePayload }

            try await app.server.start()
            let port = try #require(app.http.server.shared.localAddress?.port)

            let unsupportedNoncompressedResponse = try await app.client.get("https://localhost:\(port)/compressed") { request in
                request.headers[.acceptEncoding] = nil
            }
            #expect(unsupportedNoncompressedResponse.headers[.contentEncoding] != "gzip")
            #expect(unsupportedNoncompressedResponse.headers[.contentLength] == "\(compressiblePayload.count)")
            #expect(unsupportedNoncompressedResponse.body?.string == compressiblePayload)

            let unsupportedCompressedResponse = try await app.client.get("https://localhost:\(port)/compressed") { request in
                request.headers[.acceptEncoding]  = "gzip"
            }
            #expect(unsupportedCompressedResponse.headers[.contentEncoding] != "gzip")
            #expect(unsupportedCompressedResponse.headers[.contentLength] == "\(compressiblePayload.count)")
            #expect(unsupportedCompressedResponse.body?.string == compressiblePayload)

            app.http.server.configuration.responseCompression = .enabled

            let supportedUncompressedResponse = try await app.client.get("https://localhost:\(port)/compressed") { request in
                request.headers[.acceptEncoding] = nil
            }
            #expect(supportedUncompressedResponse.headers[.contentEncoding] != "gzip")
            #expect(supportedUncompressedResponse.headers[.contentLength] != "\(compressiblePayload.count)")
            #expect(supportedUncompressedResponse.body?.string == compressiblePayload)

            let supportedCompressedResponse = try await app.client.get("https://localhost:\(port)/compressed") { request in
                request.headers[.acceptEncoding] = "gzip"
            }
            #expect(supportedCompressedResponse.headers[.contentEncoding] == "gzip")
            #expect(supportedCompressedResponse.headers[.contentLength] != "\(compressiblePayload.count)")
            #expect(supportedCompressedResponse.body?.string == compressiblePayload)

            try await app.server.shutdown()
        }
    }

    @Test("Test Request Body Stream Gets Finalised Even If Client Abandons Connection")
    func testRequestBodyStreamGetsFinalisedEvenIfClientAbandonsConnection() async throws {
        actor WritersCount {
            enum WriterError: Error {
                case timeout
            }
            var count: Int = 0
            
            func signal() {
                count += 1
            }
            
            func wait(timeout: UInt64) async throws {
                var currentTimeout = timeout
                while count <= 0 {
                    try await Task.sleep(nanoseconds: 100)
                    currentTimeout -= 100
                    if currentTimeout <= 0 {
                        throw WriterError.timeout
                    }
                }
                count -= 1
            }
        }
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            let numRequests = ManagedAtomic<Int>(0)
            let writersStarted = WritersCount()

            app.get() { req  -> Response in
                numRequests.wrappingIncrement(ordering: .relaxed)

                #warning("Migrate")
                return try await req.eventLoop.scheduleTask(in: .milliseconds(10)) {
                    numRequests.wrappingIncrement(ordering: .relaxed)

                    return Response(status: .ok, body: .init(asyncStream: { writer in
                        await writersStarted.signal()
                        _ = try await writer.write(.end)
                    }))
                }.futureResult.get()
            }

            app.environment.arguments = ["serve"]
            await #expect(throws: Never.self) {
                try await app.startup()
            }

            let localAddress = try #require(app.http.server.shared.localAddress)
            let numberOfClients = 100

            for _ in 0 ..< numberOfClients {
                let client = try await ClientBootstrap(group: app.eventLoopGroup)
                    .connect(to: localAddress)
                    .get()
                try await client.writeAndFlush(ByteBuffer(string: "GET / HTTP/1.1\r\nhost: foo\r\n\r\n"))
                try await client.close()
            }

            for clientNumber in 0 ..< numberOfClients {
                await #expect(throws: Never.self, "Client \(clientNumber) did not complete") {
                    try await writersStarted.wait(timeout: 1_000_000)
                }
            }
            #expect(numberOfClients * 2 == numRequests.load(ordering: .relaxed))
        }
    }

    @Test("Test Live Server")
    func testLiveServer() async throws {
        try await withApp { app in
            app.routes.get("ping") { req -> String in
                return "123"
            }

            try await app.testing().test(.get, "/ping") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "123")
            }
        }
    }

    @Test("Test Custom Server")
    func testCustomServer() async throws {
        try await withApp { app in
            app.servers.use(.custom)
            #expect(app.customServer.didStart.withLockedValue({ $0 }) == false)
            #expect(app.customServer.didShutdown.withLockedValue({ $0 }) == false)

            try await app.server.start()
            #expect(app.customServer.didStart.withLockedValue({ $0 }) == true)
            #expect(app.customServer.didShutdown.withLockedValue({ $0 }) == false)

            try await app.server.shutdown()
            #expect(app.customServer.didStart.withLockedValue({ $0 }) == true)
            #expect(app.customServer.didShutdown.withLockedValue({ $0 }) == true)
        }
    }

    @Test("Test Multiple Chunk Body")
    func testMultipleChunkBody() async throws {
        try await withApp { app in
            let payload = [UInt8].random(count: 1 << 20)

            app.on(.post, "payload", body: .collect(maxSize: "1gb")) { req -> HTTPStatus in
                guard let data = req.body.data else {
                    throw Abort(.internalServerError)
                }
                #expect(payload.count == data.readableBytes)
                #expect([UInt8](data.readableBytesView) == payload)
                return .ok
            }

            var buffer = ByteBufferAllocator().buffer(capacity: payload.count)
            buffer.writeBytes(payload)
            try await app.testing(method: .running).test(.post, "payload", body: buffer) { res in
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Test Collecting Request Body")
    func testCollectedResponseBodyEnd() async throws {
        try await withApp { app in
            app.post("drain") { req in
                for try await _ in req.body {
                    // Ignore
                }
                return HTTPStatus.ok
            }

            try await app.testing(method: .running).test(.post, "drain", beforeRequest: { req in
                try req.content.encode(["hello": "world"])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Test Missing Body", .bug("https://github.com/vapor/vapor/issues/1786"))
    func testMissingBody() async throws {
        struct User: Content { }

        try await withApp { app in
            app.get("user") { req -> User in
                return try await req.content.decode(User.self)
            }

            try await app.testing().test(.get, "/user") { res in
                #expect(res.status == .unsupportedMediaType)
            }
        }
    }

    @Test("Test Too Large Port", .bug("https://github.com/vapor/vapor/issues/2245"))
    func testTooLargePort() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: .max)
            await #expect(throws: SocketAddressError.unknown(host: "127.0.0.1", port: Int.max)) {
                try await app.startup()
            }
        }
    }

    @Test("Test Early Exit Streaming Request")
    func testEarlyExitStreamingRequest() async throws {
        try await withApp { app in
            app.on(.post, "upload", body: .stream) { req -> Int in
                guard req.headers[.init("test")!] != nil else {
                    throw Abort(.badRequest)
                }

#warning("Migrate")
                let countBox = NIOLockedValueBox<Int>(0)
                let promise = req.eventLoop.makePromise(of: Int.self)
                req.body.drain { part in
                    switch part {
                    case .buffer(let buffer):
                        countBox.withLockedValue { $0 += buffer.readableBytes }
                    case .error(let error):
                        promise.fail(error)
                    case .end:
                        promise.succeed(countBox.withLockedValue({ $0 }))
                    }
                    return req.eventLoop.makeSucceededFuture(())
                }
                return try await promise.futureResult.get()
            }

            var buffer = ByteBufferAllocator().buffer(capacity: 10_000_000)
            buffer.writeString(String(repeating: "a", count: 10_000_000))

            try await app.testing(method: .running).test(.post, "upload", beforeRequest: { req in
                req.body = buffer
            }, afterResponse: { res in
                #expect(res.status == .badRequest)
            })

            try await app.testing(method: .running).test(.post, "upload", beforeRequest: { req in
                req.body = buffer
                req.headers[.init("test")!] = "a"
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }
    
    @Test("Test Echo Server")
    func testEchoServer() async throws {
        final class Context: Sendable {
            let server: NIOLockedValueBox<[String]>
            let client: NIOLockedValueBox<[String]>
            init() {
                self.server = .init([])
                self.client = .init([])
            }
        }
        let context = Context()

        try await withApp { app in
            app.on(.post, "echo", body: .stream) { request -> Response in
                Response(body: .init(stream: { writer in
                    request.body.drain { body in
                        switch body {
                        case .buffer(let buffer):
                            context.server.withLockedValue { $0.append(buffer.string) }
                            return writer.write(.buffer(buffer))
                        case .error(let error):
                            return writer.write(.error(error))
                        case .end:
                            return writer.write(.end)
                        }
                    }
                }))
            }

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.environment.arguments = ["serve"]
            try await app.startup()

            let port = try #require(app.http.server.shared.localAddress?.port, "Failed to get port")
            let request = try HTTPClient.Request(
                url: "http://localhost:\(port)/echo",
                method: .POST,
                headers: [
                    "transfer-encoding": "chunked"
                ],
                body: .stream(length: nil, { stream in
                    // We set the application to have a single event loop so we can use the same
                    // event loop here
                    let streamBox = NIOLoopBound(stream, eventLoop: app.eventLoopGroup.any())
                    return stream.write(.byteBuffer(.init(string: "foo"))).flatMap {
                        streamBox.value.write(.byteBuffer(.init(string: "bar")))
                    }.flatMap {
                        streamBox.value.write(.byteBuffer(.init(string: "baz")))
                    }
                })
            )

            final class ResponseDelegate: HTTPClientResponseDelegate {
                typealias Response = HTTPClient.Response

                let context: Context
                init(context: Context) {
                    self.context = context
                }

                func didReceiveBodyPart(
                    task: HTTPClient.Task<HTTPClient.Response>,
                    _ buffer: ByteBuffer
                ) -> EventLoopFuture<Void> {
                    self.context.client.withLockedValue { $0.append(buffer.string) }
                    return task.eventLoop.makeSucceededFuture(())
                }

                func didFinishRequest(task: HTTPClient.Task<HTTPClient.Response>) throws -> HTTPClient.Response {
                    .init(host: "", status: .ok, version: .init(major: 1, minor: 1), headers: [:], body: nil)
                }
            }
            let response = ResponseDelegate(context: context)
            _ = try await app.http.client.shared.execute(
                request: request,
                delegate: response
            ).get()

            let server = context.server.withLockedValue { $0 }
            let client = context.client.withLockedValue { $0 }
            #expect(server == ["foo", "bar", "baz"])
            #expect(client == ["foo", "bar", "baz"])
        }
    }

    @Test("Test Skip Streaming")
    func testSkipStreaming() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let app = try await Application(.testing, .shared(eventLoopGroup))
        
        app.on(.post, "echo", body: .stream) { request in
            "hello, world"
        }
        
        app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
        app.environment.arguments = ["serve"]
        try await app.startup()
        
        let port = try #require(app.http.server.shared.localAddress?.port, "Failed to get port")
        let request = try HTTPClient.Request(
            url: "http://localhost:\(port)/echo",
            method: .POST,
            headers: [
                "transfer-encoding": "chunked"
            ],
            body: .stream(length: nil, { stream in
                // We set the application to have a single event loop so we can use the same
                // event loop here
                let streamBox = NIOLoopBound(stream, eventLoop: eventLoopGroup.any())
                return stream.write(.byteBuffer(.init(string: "foo"))).flatMap {
                    streamBox.value.write(.byteBuffer(.init(string: "bar")))
                }.flatMap {
                    streamBox.value.write(.byteBuffer(.init(string: "baz")))
                }
            })
        )
        
        let a = try await app.http.client.shared.execute(request: request).get()
        #expect(a.status == .ok)
        let b = try await app.http.client.shared.execute(request: request).get()
        #expect(b.status == .ok)

        try await app.shutdown()
    }

    @Test("Test Start With Valid Socket File")
    func testStartWithValidSocketFile() async throws {
        try await withApp { app in
            let socketPath = "/tmp/\(UUID().uuidString).vapor.socket"

            app.http.server.configuration.address = .unixDomainSocket(path: socketPath)
            app.environment.arguments = ["serve"]
            await #expect(throws: Never.self) {
                try await app.startup()
            }
        }
    }

    @Test("Test Start With Unsupported Socket File")
    func testStartWithUnsupportedSocketFile() async throws {
        try await withApp { app in
            app.http.server.configuration.address = .unixDomainSocket(path: "/tmp")

            await #expect(throws: IOError.self) {
                try await app.startup()
            }
        }
    }

    @Test("Test Start With Invalid Socket File Path")
    func testStartWithInvalidSocketFilePath() async throws {
        try await withApp { app in
            app.http.server.configuration.address = .unixDomainSocket(path: "/tmp/nonexistent/vapor.socket")

            await #expect(throws: IOError.self) {
                try await app.startup()
            }
        }
    }

    @Test("Test Start With Default Hostname Configuration")
    func testStartWithDefaultHostnameConfiguration() async throws {
        try await withApp { app in
            app.http.server.configuration.address = .hostname()
            app.environment.arguments = ["serve"]

            await #expect(throws: Never.self) {
                try await app.startup()
            }
        }
    }

    @Test("Test Address Configurations")
    func testAddressConfigurations() throws {
        var configuration = HTTPServerOld.Configuration()
        #expect(configuration.address == .hostname(HTTPServerOld.Configuration.defaultHostname, port: HTTPServerOld.Configuration.defaultPort))

        configuration = HTTPServerOld.Configuration(hostname: "1.2.3.4", port: 123)
        #expect(configuration.address == .hostname("1.2.3.4", port: 123))
        #expect(configuration.hostname == "1.2.3.4")
        #expect(configuration.port == 123)

        configuration = HTTPServerOld.Configuration(address: .hostname("1.2.3.4", port: 123))
        #expect(configuration.address == .hostname("1.2.3.4", port: 123))
        #expect(configuration.hostname == "1.2.3.4")
        #expect(configuration.port == 123)

        configuration = HTTPServerOld.Configuration(address: .hostname("1.2.3.4"))
        #expect(configuration.address == .hostname("1.2.3.4"))
        #expect(configuration.hostname == "1.2.3.4")
        #expect(configuration.port == HTTPServerOld.Configuration.defaultPort)

        configuration = HTTPServerOld.Configuration(address: .hostname(port: 123))
        #expect(configuration.address == .hostname(port: 123))
        #expect(configuration.hostname == HTTPServerOld.Configuration.defaultHostname)
        #expect(configuration.port == 123)

        configuration = HTTPServerOld.Configuration(address: .hostname())
        #expect(configuration.address == .hostname())
        #expect(configuration.hostname == HTTPServerOld.Configuration.defaultHostname)
        #expect(configuration.port == HTTPServerOld.Configuration.defaultPort)

        configuration = HTTPServerOld.Configuration(address: .unixDomainSocket(path: "/path"))
        #expect(configuration.address == .unixDomainSocket(path: "/path"))

        
        // Test mutating a config that was originally a socket path
        configuration = HTTPServerOld.Configuration(address: .unixDomainSocket(path: "/path"))
        #expect(configuration.address == .unixDomainSocket(path: "/path"))

        configuration.hostname = "1.2.3.4"
        #expect(configuration.hostname == "1.2.3.4")
        #expect(configuration.port == HTTPServerOld.Configuration.defaultPort)
        #expect(configuration.address == .hostname("1.2.3.4"))

        configuration.address = .unixDomainSocket(path: "/path")
        #expect(configuration.hostname == HTTPServerOld.Configuration.defaultHostname)
        #expect(configuration.port == HTTPServerOld.Configuration.defaultPort)
        #expect(configuration.address == .unixDomainSocket(path: "/path"))

        configuration.port = 123
        #expect(configuration.hostname == HTTPServerOld.Configuration.defaultHostname)
        #expect(configuration.port == 123)
        #expect(configuration.address == .hostname(port: 123))

        configuration.hostname = "1.2.3.4"
        #expect(configuration.hostname == "1.2.3.4")
        #expect(configuration.port == 123)
        #expect(configuration.address == .hostname("1.2.3.4", port: 123))

        configuration.address = .hostname()
        #expect(configuration.hostname == HTTPServerOld.Configuration.defaultHostname)
        #expect(configuration.port == HTTPServerOld.Configuration.defaultPort)
        #expect(configuration.address == .hostname())
    }

    @Test("Test Quiesce Keep Alive Connections")
    func testQuiesceKeepAliveConnections() async throws {
        try await withApp { app in
            app.get("hello") { req in
                "world"
            }

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.environment.arguments = ["serve"]
            try await app.startup()

            let port = try #require(app.http.server.shared.localAddress?.port, "Failed to get port")
            let request = try HTTPClient.Request(
                url: "http://localhost:\(port)/hello",
                method: .GET,
                headers: ["connection": "keep-alive"]
            )
            let a = try await app.http.client.shared.execute(request: request).get()
            let newHeaders = HTTPFields(a.headers, splitCookie: false)
            #expect(newHeaders.connection == .keepAlive)
        }
    }

    @Test("Test Request Body Stream Gets Finalised Even If Client Disappears")
    func testRequestBodyStreamGetsFinalisedEvenIfClientDisappears() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            let serverIsFinalisedPromise = app.eventLoopGroup.any().makePromise(of: Void.self)
            let allDonePromise = app.eventLoopGroup.any().makePromise(of: Void.self)

            app.on(.post, "hello", body: .stream) { req -> Response in
                return Response(body: .init(stream: { writer in
                    req.body.drain { stream in
                        switch stream {
                        case .buffer:
                            ()
                        case .end:
                            serverIsFinalisedPromise.succeed(())
                            writer.write(.end, promise: nil)
                        case .error(let error):
                            serverIsFinalisedPromise.fail(error)
                            writer.write(.error(error), promise: nil)
                        }
                        return allDonePromise.futureResult
                    }
                }))
            }

            app.environment.arguments = ["serve"]
            try await app.startup()

            let ip = try #require(app.http.server.shared.localAddress?.ipAddress)
            let port = try #require(app.http.server.shared.localAddress?.port)

            let tenMB = ByteBuffer(repeating: 0x41, count: 10 * 1024 * 1024)
            // This originally was either a read timeout or deadline exceeded error
            await #expect(throws: HTTPClientError.deadlineExceeded) {
                try await app.http.client.shared.execute(.POST,
                                                         url: "http://\(ip):\(port)/hello",
                                                         body: .byteBuffer(tenMB),
                                                         deadline: .now() + .milliseconds(100)).get()
            }

            allDonePromise.succeed(()) // This unblocks the server
            await #expect(throws: NIOHTTP1.HTTPParserError.invalidEOFState) {
                try await serverIsFinalisedPromise.futureResult.get()
            }
        }
    }

    @Test("Test Request Body Backpressure")
    func testRequestBodyBackpressureWorks() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            let numberOfTimesTheServerGotOfferedBytes = ManagedAtomic<Int>(0)
            let bytesTheServerSaw = ManagedAtomic<Int>(0)
            let bytesTheClientSent = ManagedAtomic<Int>(0)
            let serverSawEnd = ManagedAtomic<Bool>(false)
            let serverSawRequest = ManagedAtomic<Bool>(false)
            let allDonePromise = app.eventLoopGroup.any().makePromise(of: Void.self)

            app.on(.post, "hello", body: .stream) { req -> Response in
                #expect(serverSawRequest.compareExchange(expected: false, desired: true, ordering: .relaxed).exchanged == true)

                return Response(body: .init(stream: { writer in
                    req.body.drain { stream in
                        switch stream {
                        case .buffer(let bytes):
                            numberOfTimesTheServerGotOfferedBytes.wrappingIncrement(ordering: .relaxed)
                            bytesTheServerSaw.wrappingIncrement(by: bytes.readableBytes, ordering: .relaxed)
                        case .end:
                            Issue.record("backpressure should prevent us seeing the end of the request.")
                            serverSawEnd.store(true, ordering: .relaxed)
                            writer.write(.end, promise: nil)
                        case .error(let error):
                            writer.write(.error(error), promise: nil)
                        }
                        return allDonePromise.futureResult
                    }
                }))
            }

            app.environment.arguments = ["serve"]
            try await app.startup()

            let ip = try #require(app.http.server.shared.localAddress?.ipAddress)
            let port = try #require(app.http.server.shared.localAddress?.port)

            final class ResponseDelegate: HTTPClientResponseDelegate {
                typealias Response = Void

                private let bytesTheClientSent: ManagedAtomic<Int>

                init(bytesTheClientSent: ManagedAtomic<Int>) {
                    self.bytesTheClientSent = bytesTheClientSent
                }

                func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
                    return ()
                }

                func didSendRequestPart(task: HTTPClient.Task<Response>, _ part: IOData) {
                    self.bytesTheClientSent.wrappingIncrement(by: part.readableBytes, ordering: .relaxed)
                }
            }

            let tenMB = ByteBuffer(repeating: 0x41, count: 10 * 1024 * 1024)
            let request = try! HTTPClient.Request(url: "http://\(ip):\(port)/hello",
                                                  method: .POST,
                                                  headers: [:],
                                                  body: .byteBuffer(tenMB))
            let delegate = ResponseDelegate(bytesTheClientSent: bytesTheClientSent)
            // This originally was either a read timeout or deadline exceeded error
            await #expect(throws: HTTPClientError.deadlineExceeded) {
                try await app.http.client.shared.execute(request: request,
                                                         delegate: delegate,
                                                         deadline: .now() + .milliseconds(500)).get()
            }

            #expect(1 == numberOfTimesTheServerGotOfferedBytes.load(ordering: .relaxed))
            #expect(tenMB.readableBytes > bytesTheServerSaw.load(ordering: .relaxed))
            #expect(tenMB.readableBytes > bytesTheClientSent.load(ordering: .relaxed))
            #expect(0 == bytesTheClientSent.load(ordering: .relaxed)) // We'd only see this if we sent the full 10 MB.
            #expect(serverSawEnd.load(ordering: .relaxed) == false)
            #expect(serverSawRequest.load(ordering: .relaxed) == true)

            allDonePromise.succeed(())
        }
    }

    @Test("Test Can Override Cert Validation")
    func testCanOverrideCertValidation() async throws {
        try await withApp { app in
            guard let clientCertPath = Bundle.module.url(forResource: "expired", withExtension: "crt"),
                  let clientKeyPath = Bundle.module.url(forResource: "expired", withExtension: "key") else {
                Issue.record("Cannot load expired cert and associated key")
                return
            }

            let cert = try NIOSSLCertificate(file: clientCertPath.path, format: .pem)
            let key = try NIOSSLPrivateKey(file: clientKeyPath.path, format: .pem)

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            var serverConfig = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(cert)], privateKey: .privateKey(key))
            serverConfig.certificateVerification = .noHostnameVerification

            app.http.server.configuration.tlsConfiguration = serverConfig
            app.http.server.configuration.customCertificateVerifyCallback = { @Sendable peerCerts, successPromise in
                // This lies and accepts the above cert, which has actually expired.
                #expect(peerCerts == [cert])
                successPromise.succeed(.certificateVerified)
            }

            // We need to disable verification on the client, because the cert we're using has expired, and we want to
            // _send_ a client cert.
            var clientConfig = TLSConfiguration.makeClientConfiguration()
            clientConfig.certificateVerification = .none
            clientConfig.certificateChain = [.certificate(cert)]
            clientConfig.privateKey = .privateKey(key)
            app.http.client.configuration.tlsConfiguration = clientConfig

            app.environment.arguments = ["serve"]

            app.get("hello") { req in
                "world"
            }

            try await app.startup()
            let ip = try #require(app.http.server.shared.localAddress?.ipAddress)
            let port = try #require(app.http.server.shared.localAddress?.port)

            let request = try HTTPClient.Request(
                url: "https://\(ip):\(port)/hello",
                method: .GET
            )
            let a = try await app.http.client.shared.execute(request: request).get()
            #expect(a.body == ByteBuffer(string: "world"))
        }
    }

    @Test("Test Can Change Configuration Dynamically")
    func testCanChangeConfigurationDynamically() async throws {
        try await withApp { app in
            guard let clientCertPath = Bundle.module.url(forResource: "expired", withExtension: "crt"),
                  let clientKeyPath = Bundle.module.url(forResource: "expired", withExtension: "key") else {
                Issue.record("Cannot load expired cert and associated key")
                return
            }

            let cert = try NIOSSLCertificate(file: clientCertPath.path, format: .pem)
            let key = try NIOSSLPrivateKey(file: clientKeyPath.path, format: .pem)

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.http.server.configuration.serverName = "Old"

            /// We need to disable verification on the client, because the cert we're using has expired
            var clientConfig = TLSConfiguration.makeClientConfiguration()
            clientConfig.certificateVerification = .none
            clientConfig.certificateChain = [.certificate(cert)]
            clientConfig.privateKey = .privateKey(key)
            app.http.client.configuration.tlsConfiguration = clientConfig
            app.http.client.configuration.maximumUsesPerConnection = 1

            app.environment.arguments = ["serve"]

            app.get("hello") { req in
                "world"
            }

            try await app.startup()
            let ip = try #require(app.http.server.shared.localAddress?.ipAddress)
            let port = try #require(app.http.server.shared.localAddress?.port)

            /// Make a regular request
            let a = try await app.http.client.shared.execute(
                request: try HTTPClient.Request(
                    url: "http://\(ip):\(port)/hello",
                    method: .GET
                )
            ).get()
            #expect(a.headers["server"] == ["Old"])
            #expect(a.body == ByteBuffer(string: "world"))

            /// Configure server name without stopping the server
            app.http.server.configuration.serverName = "New"
            /// Configure TLS without stopping the server
            var serverConfig = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(cert)], privateKey: .privateKey(key))
            serverConfig.certificateVerification = .noHostnameVerification

            app.http.server.configuration.tlsConfiguration = serverConfig
            app.http.server.configuration.customCertificateVerifyCallback = { @Sendable peerCerts, successPromise in
                /// This lies and accepts the above cert, which has actually expired.
                #expect(peerCerts == [cert])
                successPromise.succeed(.certificateVerified)
            }

            /// Make a TLS request this time around
            let b = try await app.http.client.shared.execute(
                request: try HTTPClient.Request(
                    url: "https://\(ip):\(port)/hello",
                    method: .GET
                )
            ).get()
            #expect(b.headers["server"] == ["New"])
            #expect(b.body == ByteBuffer(string: "world"))

            /// Non-TLS request should now fail
            await #expect(throws: HTTPClientError.remoteConnectionClosed) {
                try await app.http.client.shared.execute(
                    request: try HTTPClient.Request(
                        url: "http://\(ip):\(port)/hello",
                        method: .GET
                    )).get()
            }
        }
    }

    @Test("Test Configuration Has Actual Port After Start")
    func testConfigurationHasActualPortAfterStart() async throws {
        try await withApp { app in
            app.environment.arguments = ["serve"]
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            try await app.startup()

            #expect(app.serverConfiguration.port != 0)
            #expect(app.serverConfiguration.port == app.sharedNewAddress.withLockedValue({ $0 })?.port)
        }
    }
}

extension Application.Servers.Provider {
    static var custom: Self {
        .init {
            $0.servers.use { $0.customServer }
        }
    }
}

extension Application {
    struct Key: StorageKey {
        typealias Value = CustomServer
    }
    
    var customServer: CustomServer {
        if let existing = self.storage[Key.self] {
            return existing
        } else {
            let new = CustomServer()
            self.storage[Key.self] = new
            return new
        }
    }
}

final class CustomServer: Server, Sendable {
    let didStart: NIOLockedValueBox<Bool>
    let didShutdown: NIOLockedValueBox<Bool>
    
    init() {
        self.didStart = .init(false)
        self.didShutdown = .init(false)
    }
    
    func start() async throws {
        self.didStart.withLockedValue { $0 = true }
    }
    
    func shutdown() async throws {
        self.didShutdown.withLockedValue { $0 = true }
    }
}

private extension ByteBuffer {
    init?(base64String: String) {
        guard let decoded = Data(base64Encoded: base64String) else { return nil }
        var buffer = ByteBufferAllocator().buffer(capacity: decoded.count)
        buffer.writeBytes(decoded)
        self = buffer
    }
}

#warning("Remove when future NIO implementation fixes this")
extension SocketAddressError: @retroactive Equatable {
    public static func == (lhs: SocketAddressError, rhs: SocketAddressError) -> Bool {
        switch lhs {
        case .unsupported:
            return rhs == .unsupported
        case .unixDomainSocketPathTooLong:
            return rhs == .unixDomainSocketPathTooLong
        case .failedToParseIPString(let string):
            if case .failedToParseIPString(let other) = rhs {
                return string == other
            } else {
                return false
            }
        case .unknown(host: let host, port: let port):
            if case .unknown(host: let otherHost, port: let otherPort) = rhs {
                return host == otherHost && port == otherPort
            } else {
                return false
            }
        }
    }
    

}
