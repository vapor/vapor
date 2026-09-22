import ServiceLifecycle
import Testing
import VaporTesting

@testable import Vapor

@Suite("HTTP Server Configuration Tests")
struct HTTPServerConfigurationTests {

    @Suite("HTTP/2 configuration")
    struct HTTP2Tests {
        @Test("Default values")
        func testDefaultValues() {
            let http2 = ServerConfiguration.HTTP2.defaults
            #expect(http2.maxFrameSize == ServerConfiguration.HTTP2.defaultMaxFrameSize)
            #expect(http2.targetWindowSize == ServerConfiguration.HTTP2.defaultTargetWindowSize)
            #expect(http2.maxConcurrentStreams == ServerConfiguration.HTTP2.defaultMaxConcurrentStreams)
            #expect(http2.gracefulShutdown.maximumGracefulShutdownDuration == nil)
        }

        @Test("Custom values")
        func testCustomValues() {
            let http2 = ServerConfiguration.HTTP2(
                maxFrameSize: 1,
                targetWindowSize: 2,
                maxConcurrentStreams: 3,
                gracefulShutdown: .init(maximumGracefulShutdownDuration: .seconds(4))
            )
            #expect(http2.maxFrameSize == 1)
            #expect(http2.targetWindowSize == 2)
            #expect(http2.maxConcurrentStreams == 3)
            #expect(http2.gracefulShutdown.maximumGracefulShutdownDuration == .seconds(4))
        }

        @Test("Partial custom values fall back to defaults")
        func testPartialCustomValues() {
            let http2 = ServerConfiguration.HTTP2(maxFrameSize: 5)
            #expect(http2.maxFrameSize == 5)
            #expect(http2.targetWindowSize == ServerConfiguration.HTTP2.defaultTargetWindowSize)
            #expect(http2.maxConcurrentStreams == ServerConfiguration.HTTP2.defaultMaxConcurrentStreams)
            #expect(http2.gracefulShutdown.maximumGracefulShutdownDuration == nil)
        }
    }

    @Suite("HTTP/3 configuration")
    struct HTTP3Tests {
        @Test("Default values")
        func defaultValues() {
            let http3 = ServerConfiguration.HTTP3.defaults
            #expect(http3.preferHuffmanEncoding)
            #expect(http3.quicConfiguration == .defaults)
            #expect(http3.connectionSettings == .defaults)

            let quic = ServerConfiguration.HTTP3.QUICConfiguration.defaults
            #expect(quic.serverName == "")
            #expect(quic.keyExchangeGroup == .x25519)
            #expect(quic.maxIdleTimeout == .seconds(30))
            #expect(quic.initialMaxData == 1024 * 1024)
            #expect(quic.initialMaxStreamDataBidirectionalLocal == 1024 * 1024)
            #expect(quic.initialMaxStreamDataBidirectionalRemote == 1024 * 1024)
            #expect(quic.initialMaxStreamDataUnidirectional == 1024 * 1024)
            #expect(quic.initialMaxStreamsBidirectional == 100)
            #expect(quic.initialMaxStreamsUnidirectional == 100)
            #expect(quic.keepAliveInterval == nil)
            #expect(quic.sendRetry == false)
            #expect(quic.keyLogPath == nil)
            #expect(quic.qLogConfiguration == nil)

            let connection = ServerConfiguration.HTTP3.ConnectionSettings.defaults
            #expect(connection.qpackMaximumTableCapacity == 0)
            #expect(connection.qpackBlockedStreams == 0)
            #expect(connection.maximumFieldSectionSize == nil)
        }

        @Test("Custom values")
        func customValues() {
            var http3 = ServerConfiguration.HTTP3(
                preferHuffmanEncoding: false,
                quicConfiguration: .defaults,
                connectionSettings: .defaults
            )
            #expect(http3.preferHuffmanEncoding == false)
            #expect(http3.quicConfiguration == .defaults)
            #expect(http3.connectionSettings == .defaults)

            http3.quicConfiguration.keyExchangeGroup = .secp256
            #expect(http3.quicConfiguration.keyExchangeGroup == .secp256)

            http3.quicConfiguration.keyExchangeGroup = .secp384
            #expect(http3.quicConfiguration.keyExchangeGroup == .secp384)

            http3.quicConfiguration.keyExchangeGroup = .x25519MLKEM768
            #expect(http3.quicConfiguration.keyExchangeGroup == .x25519MLKEM768)

            http3.quicConfiguration.qLogConfiguration = .init(path: "test", topic: "test", description: "test")
            #expect(http3.quicConfiguration.qLogConfiguration != nil)
        }
    }

    @Suite("Supported HTTP versions")
    struct SupportedHTTPVersionsTests {
        @Test("Defaults to HTTP/1.1 only")
        func testDefault() {
            let config = ServerConfiguration(address: .hostname("localhost", port: 8080))
            #expect(config.httpVersions == [.http1_1])
        }

        @Test("HTTP/1.1, HTTP/2 and HTTP/3 are distinct versions")
        func testDistinctVersions() {
            let versions: Set<ServerConfiguration.HTTPVersion> = [.http1_1, .http2, .http3]
            #expect(versions.count == 3)
        }

        @Test("HTTP/2 versions are equal regardless of configuration")
        func testHTTP2EqualByVersionOnly() {
            // Equality and hashing are by protocol version only, so two HTTP/2 entries with
            // different configuration collapse to a single set member.
            let a: ServerConfiguration.HTTPVersion = .http2
            let b: ServerConfiguration.HTTPVersion = .http2(config: .init(maxFrameSize: 1))
            #expect(a == b)
            #expect(Set([a, b]).count == 1)
        }

        @Test("HTTP/3 versions are equal regardless of configuration")
        func http3EqualByVersionOnly() {
            // Equality and hashing are by protocol version only,
            // so two HTTP/3 entries with different configuration collapse to a single set member.
            let a: ServerConfiguration.HTTPVersion = .http3
            let b: ServerConfiguration.HTTPVersion = .http3(
                config: .init(
                    preferHuffmanEncoding: false,
                    quicConfiguration: .defaults,
                    connectionSettings: .defaults
                )
            )
            #expect(a == b)
            #expect(Set([a, b]).count == 1)
        }
    }

    @Suite("Preflight validation")
    struct PreflightValidationTests {
        // HTTP/2 and HTTP/3 require TLS, so any version set containing HTTP/2 or HTTP/3 must be rejected over
        // plaintext — even when HTTP/1.1 is also present.
        @Test(
            "HTTP/2 and HTTP/3 requested over plaintext throw",
            arguments: [
                [ServerConfiguration.HTTPVersion.http2, .http3],
                [.http1_1, .http2, .http3],
            ] as [Set<ServerConfiguration.HTTPVersion>])
        func testHTTP2AndHTTP3WithoutTLSFails(_ versions: Set<ServerConfiguration.HTTPVersion>) async throws {
            try await withApp { app in
                app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
                app.serverConfiguration.httpVersions = versions
                // tlsConfiguration is intentionally left nil: HTTP/2 and HTTP/3 both require TLS.

                await #expect(throws: NIOHTTPServerAdapterError.http2And3RequireTLS) {
                    try await app.server.run()
                }
            }
        }

        @Test("An empty httpVersions set throws")
        func testEmptyHTTPVersionsFails() async throws {
            try await withApp { app in
                app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
                app.serverConfiguration.httpVersions = []

                await #expect(throws: NIOHTTPServerAdapterError.noHTTPVersionsSpecified) {
                    try await app.server.run()
                }
            }
        }
    }
}
