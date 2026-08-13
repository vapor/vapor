@testable import Vapor
import VaporTesting
import ServiceLifecycle
import Testing

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

    @Suite("Supported HTTP versions")
    struct SupportedHTTPVersionsTests {
        @Test("Defaults to HTTP/1.1 only")
        func testDefault() {
            let config = ServerConfiguration(address: .hostname("localhost", port: 8080))
            #expect(config.httpVersions == [.http1_1])
        }

        @Test("HTTP/1.1 and HTTP/2 are distinct versions")
        func testDistinctVersions() {
            let versions: Set<ServerConfiguration.HTTPVersion> = [.http1_1, .http2(config: .defaults)]
            #expect(versions.count == 2)
        }

        @Test("HTTP/2 versions are equal regardless of configuration")
        func testHTTP2EqualByVersionOnly() {
            // Equality and hashing are by protocol version only, so two HTTP/2 entries with
            // different configuration collapse to a single set member.
            let a: ServerConfiguration.HTTPVersion = .http2(config: .defaults)
            let b: ServerConfiguration.HTTPVersion = .http2(config: .init(maxFrameSize: 1))
            #expect(a == b)
            #expect(Set([a, b]).count == 1)
        }
    }

    @Suite("Preflight validation")
    struct PreflightValidationTests {
        // HTTP/2 requires TLS, so any version set containing HTTP/2 must be rejected over
        // plaintext — even when HTTP/1.1 is also present.
        @Test("HTTP/2 requested over plaintext throws", arguments: [
            [ServerConfiguration.HTTPVersion.http2(config: .defaults)],
            [.http1_1, .http2(config: .defaults)],
        ] as [Set<ServerConfiguration.HTTPVersion>])
        func testHTTP2WithoutTLSFails(_ versions: Set<ServerConfiguration.HTTPVersion>) async throws {
            try await withApp { app in
                app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
                app.serverConfiguration.httpVersions = versions
                // tlsConfiguration is intentionally left nil: HTTP/2 requires TLS.

                do {
                    try await app.server.run()
                    Issue.record("Expected run() to throw for \(versions).")
                } catch NIOHTTPServerAdapterError.http2RequiresTLS {
                    // Expected.
                } catch {
                    Issue.record("Expected http2RequiresTLS but got \(error).")
                }
            }
        }

        @Test("An empty httpVersions set throws")
        func testEmptyHTTPVersionsFails() async throws {
            try await withApp { app in
                app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
                app.serverConfiguration.httpVersions = []

                do {
                    try await app.server.run()
                    Issue.record("Expected run() to throw for an empty httpVersions set.")
                } catch NIOHTTPServerAdapterError.noHTTPVersionsSpecified {
                    // Expected.
                } catch {
                    Issue.record("Expected noHTTPVersionsSpecified but got \(error).")
                }
            }
        }
    }
}
