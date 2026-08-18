@testable import Vapor
import VaporTesting
import AsyncHTTPClient
import Crypto
import ServiceLifecycleTestKit
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import ServiceLifecycle
import Testing
import Foundation
import X509
import SwiftASN1
import RoutingKit

@Suite("Server TLS Tests")
struct ServerTLSTests {

    // MARK: - Configuration

    @Test("tlsConfiguration defaults to nil and is settable")
    func testTLSConfigurationProperty() {
        var config = ServerConfiguration(address: .hostname("localhost", port: 8080))
        #expect(config.tlsConfiguration == nil)
        #expect(config.isTLSEnabled == false)
        config.tlsConfiguration = .pemFile(certificateChainPath: "/x", privateKeyPath: "/y")
        #expect(config.tlsConfiguration != nil)
        #expect(config.isTLSEnabled == true)
    }

    @Test("tlsConfiguration can be supplied to the initialiser")
    func testTLSConfigurationViaInitialiser() {
        let config = ServerConfiguration(
            address: .hostname("example.com", port: 443),
            tlsConfiguration: .pemFile(certificateChainPath: "/x", privateKeyPath: "/y")
        )
        #expect(config.isTLSEnabled == true)
        #expect(config.addressDescription == "https://example.com:443")
    }

    @Test("addressDescription uses http scheme without TLS")
    func testAddressDescriptionHTTP() {
        let config = ServerConfiguration(address: .hostname("example.com", port: 443))
        #expect(config.addressDescription == "http://example.com:443")
    }

    @Test("addressDescription uses https scheme with TLS")
    func testAddressDescriptionHTTPS() {
        var config = ServerConfiguration(address: .hostname("example.com", port: 443))
        config.tlsConfiguration = .pemFile(certificateChainPath: "/x", privateKeyPath: "/y")
        #expect(config.addressDescription == "https://example.com:443")
    }

    @Test("addressDescription for unix domain socket")
    func testAddressDescriptionUnixSocket() {
        var config = ServerConfiguration(address: .unixDomainSocket(path: "/tmp/x.sock"))
        #expect(config.addressDescription == "http+unix: /tmp/x.sock")
        config.tlsConfiguration = .pemFile(certificateChainPath: "/x", privateKeyPath: "/y")
        #expect(config.addressDescription == "https+unix: /tmp/x.sock")
    }

    // MARK: - Serving over TLS

    @Test("Server serves over TLS with PEM file credentials", .timeLimit(.minutes(1)))
    func testServesOverTLSWithPEMFile() async throws {
        try await withApp { app in
            let credentials = try TestCredentials.localhost()
            app.serverConfiguration.tlsConfiguration = .pemFile(
                certificateChainPath: credentials.certificatePath,
                privateKeyPath: credentials.privateKeyPath
            )
            app.get("hello") { _ in "world" }

            try await withRunningApp(app: app, hostname: "127.0.0.1") { port in
                // Pinning the server's certificate as the client's only trust root means the
                // handshake succeeds *only* if the server presents exactly this certificate. That
                // makes this a test of which certificate we serve, not merely that TLS is enabled.
                try await withTLSClient(trustingOnly: credentials.nioCertificate) { client in
                    let response = try await client.execute(
                        HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                        timeout: .seconds(10)
                    )
                    #expect(response.status == .ok)
                    #expect(try await response.body.collect(upTo: 1024).string == "world")
                }
            }
        }
    }

    @Test("Server serves over TLS with in-memory certificate", .timeLimit(.minutes(1)))
    func testServesOverTLSWithInMemoryCertificate() async throws {
        try await withApp { app in
            let credentials = try TestCredentials.localhost()
            app.serverConfiguration.tlsConfiguration = .inMemory(
                certificateChain: [credentials.certificate],
                privateKey: credentials.privateKey
            )
            app.get("hello") { _ in "world" }

            try await withRunningApp(app: app, hostname: "127.0.0.1") { port in
                try await withTLSClient(trustingOnly: credentials.nioCertificate) { client in
                    let response = try await client.execute(
                        HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                        timeout: .seconds(10)
                    )
                    #expect(response.status == .ok)
                    #expect(try await response.body.collect(upTo: 1024).string == "world")
                }
            }
        }
    }

    @Test("Server serves over TLS with reloading PEM file credentials", .timeLimit(.minutes(1)))
    func testServesOverTLSWithReloadingPEMFile() async throws {
        try await withApp { app in
            let credentials = try TestCredentials.localhost()
            app.serverConfiguration.tlsConfiguration = .pemFile(
                certificateChainPath: credentials.certificatePath,
                privateKeyPath: credentials.privateKeyPath,
                refreshInterval: .seconds(60)
            )
            app.get("hello") { _ in "world" }

            try await withRunningApp(app: app, hostname: "127.0.0.1") { port in
                try await withTLSClient(trustingOnly: credentials.nioCertificate) { client in
                    let response = try await client.execute(
                        HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                        timeout: .seconds(10)
                    )
                    #expect(response.status == .ok)
                    #expect(try await response.body.collect(upTo: 1024).string == "world")
                }
            }
        }
    }

    @Test("Server presents the rotated certificate after the PEM files change", .timeLimit(.minutes(1)))
    func testReloadsRotatedCertificate() async throws {
        let first = try SelfSignedCredentials.generate()
        let second = try SelfSignedCredentials.generate()

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let certificatePath = directory.appendingPathComponent("cert.pem").path
        let privateKeyPath = directory.appendingPathComponent("key.pem").path
        try first.certificatePEM.write(toFile: certificatePath, atomically: true, encoding: .utf8)
        try first.privateKeyPEM.write(toFile: privateKeyPath, atomically: true, encoding: .utf8)

        try await withApp { app in
            app.serverConfiguration.tlsConfiguration = .pemFile(
                certificateChainPath: certificatePath,
                privateKeyPath: privateKeyPath,
                refreshInterval: .milliseconds(50)
            )
            app.get("hello") { _ in "world" }

            try await withRunningApp(app: app, hostname: "127.0.0.1") { port in
                // Sanity check that the first certificate is being served.
                try await withTLSClient(trustingOnly: first.nioCertificate) { client in
                    let response = try await client.execute(
                        HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                        timeout: .seconds(10)
                    )
                    #expect(response.status == .ok)
                }

                try second.certificatePEM.write(toFile: certificatePath, atomically: true, encoding: .utf8)
                try second.privateKeyPEM.write(toFile: privateKeyPath, atomically: true, encoding: .utf8)

                // Wait until server presents the second certificate.
                var rotated = false
                for _ in 0..<50 {
                    do {
                        try await withTLSClient(trustingOnly: second.nioCertificate) { client in
                            _ = try await client.execute(
                                HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                                timeout: .milliseconds(500)
                            )
                        }
                        rotated = true
                        break
                    } catch {
                        try await Task.sleep(for: .milliseconds(100))
                    }
                }
                #expect(rotated, "server never presented the rotated certificate")
            }
        }
    }

    @Test("Graceful shutdown drains in-flight requests with reloading TLS", .timeLimit(.minutes(1)))
    func testGracefulShutdownDrainsInFlightRequestsWithReloadingTLS() async throws {
        try await withApp { app in
            let credentials = try TestCredentials.localhost()
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.serverConfiguration.tlsConfiguration = .pemFile(
                certificateChainPath: credentials.certificatePath,
                privateKeyPath: credentials.privateKeyPath,
                refreshInterval: .seconds(60)
            )
            let (requestStarted, startedContinuation) = AsyncStream<Void>.makeStream()
            app.get("slow") { _ in
                startedContinuation.yield()
                try await Task.sleep(for: .milliseconds(500))
                return "done"
            }

            try await app.boot()
            // Resolve app.server once because concurrent first accesses can each create an adapter.
            let server = app.server

            try await testGracefulShutdown { trigger in
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { try await server.run() }

                    let address = try await server.listeningAddress
                    let port = try #require(address.port)
                    group.addTask {
                        try await withTLSClient(trustingOnly: credentials.nioCertificate) { client in
                            let response = try await client.execute(
                                HTTPClientRequest(url: "https://127.0.0.1:\(port)/slow"),
                                timeout: .seconds(10)
                            )
                            #expect(response.status == .ok)
                            #expect(try await response.body.collect(upTo: 1024).string == "done")
                        }
                    }

                    // Shut down while the request is in flight. It must still complete.
                    var started = requestStarted.makeAsyncIterator()
                    await started.next()
                    trigger.triggerGracefulShutdown()
                    try await group.waitForAll()
                }
            }
        }
    }

    @Test("Server serves plaintext without TLS configuration", .timeLimit(.minutes(1)))
    func testServesPlaintextWithoutTLSConfiguration() async throws {
        try await withApp { app in
            app.get("hello") { _ in "world" }

            try await withRunningApp(app: app, hostname: "127.0.0.1") { port in
                let response = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/hello"),
                    timeout: .seconds(10)
                )
                #expect(response.status == .ok)
                #expect(try await response.body.collect(upTo: 1024).string == "world")
            }
        }
    }

    // MARK: - Negative paths

    @Test("Plaintext request to a TLS server fails", .timeLimit(.minutes(1)))
    func testPlaintextRequestToTLSServerFails() async throws {
        try await withApp { app in
            let credentials = try TestCredentials.localhost()
            app.serverConfiguration.tlsConfiguration = .pemFile(
                certificateChainPath: credentials.certificatePath,
                privateKeyPath: credentials.privateKeyPath
            )
            app.get("hello") { _ in "world" }

            try await withRunningApp(app: app, hostname: "127.0.0.1") { port in
                // Happy path first
                try await withTLSClient(trustingOnly: credentials.nioCertificate) { client in
                    let response = try await client.execute(
                        HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                        timeout: .seconds(10)
                    )
                    #expect(try await response.body.collect(upTo: 1024).string == "world")
                }

                // The server cannot parse plaintext HTTP bytes as a TLS handshake, so it drops the
                // connection rather than answering.
                await #expect(throws: (any Error).self) {
                    try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/hello"),
                        timeout: .seconds(5)
                    )
                }
            }
        }
    }

    @Test("Client that does not trust the server's certificate is rejected", .timeLimit(.minutes(1)))
    func testUntrustedClientIsRejected() async throws {
        try await withApp { app in
            let credentials = try TestCredentials.localhost()
            app.serverConfiguration.tlsConfiguration = .inMemory(
                certificateChain: [credentials.certificate],
                privateKey: credentials.privateKey
            )
            app.get("hello") { _ in "world" }

            try await withRunningApp(app: app, hostname: "127.0.0.1") { port in
                // Without setting the trust store this will fail
                let error = await #expect(throws: (any Error).self) {
                    try await withTLSClient { client in
                        try await client.execute(
                            HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                            timeout: .seconds(2)
                        )
                    }
                }
                #expect(error is NIOSSLError || error is NIOSSLExtraError, "expected a TLS failure, got \(String(describing: error))")

                // Check it actually works
                try await withTLSClient(trustingOnly: credentials.nioCertificate) { client in
                    let response = try await client.execute(
                        HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                        timeout: .seconds(10)
                    )
                    #expect(response.status == .ok)
                }
            }
        }
    }

    @Test("Server startup fails when the PEM files do not exist", .timeLimit(.minutes(1)))
    func testInvalidPEMPathFailsServerStartup() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("localhost", port: 0)
            app.serverConfiguration.tlsConfiguration = .pemFile(
                certificateChainPath: "/nonexistent/certificate.crt",
                privateKeyPath: "/nonexistent/private.key"
            )
            app.get("hello") { _ in "world" }

            try await app.boot()

            await #expect(throws: (any Error).self) {
                try await app.server.run()
            }
        }
    }

    @Test("Server startup fails when the reloading PEM files do not exist", .timeLimit(.minutes(1)))
    func testInvalidReloadingPEMPathFailsServerStartup() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("localhost", port: 0)
            app.serverConfiguration.tlsConfiguration = .pemFile(
                certificateChainPath: "/nonexistent/certificate.crt",
                privateKeyPath: "/nonexistent/private.key",
                refreshInterval: .seconds(60)
            )
            app.get("hello") { _ in "world" }

            try await app.boot()

            await #expect(throws: (any Error).self) {
                try await app.server.run()
            }
        }
    }

    @Test("Server startup fails when the refresh interval is not positive", .timeLimit(.minutes(1)))
    func testNonPositiveRefreshIntervalFailsServerStartup() async throws {
        try await withApp { app in
            let credentials = try TestCredentials.localhost()
            app.serverConfiguration.address = .hostname("localhost", port: 0)
            app.serverConfiguration.tlsConfiguration = .pemFile(
                certificateChainPath: credentials.certificatePath,
                privateKeyPath: credentials.privateKeyPath,
                refreshInterval: .zero
            )
            app.get("hello") { _ in "world" }

            try await app.boot()

            await #expect(throws: (any Error).self) {
                try await app.server.run()
            }
        }
    }

    @Test("Waiting on the listening address fails when startup fails", .timeLimit(.minutes(1)))
    func testListeningAddressFailsWhenStartupFails() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("localhost", port: 0)
            app.serverConfiguration.tlsConfiguration = .pemFile(
                certificateChainPath: "/nonexistent/certificate.crt",
                privateKeyPath: "/nonexistent/private.key"
            )

            try await app.boot()

            await #expect(throws: (any Error).self) {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try? await app.server.run()
                    }
                    _ = try await app.server.listeningAddress
                    group.cancelAll()
                }
            }
        }
    }

    @Test("HTTP/1.1 client is served when the server also offers HTTP/2", .timeLimit(.minutes(1)))
    func testHTTP1ClientAgainstHTTP2EnabledServer() async throws {
        try await withApp { app in
            let credentials = try TestCredentials.localhost()
            app.serverConfiguration.tlsConfiguration = .inMemory(
                certificateChain: [credentials.certificate],
                privateKey: credentials.privateKey
            )
            app.serverConfiguration.httpVersions = [.http1_1, .http2(config: .defaults)]
            app.get("hello") { _ in "world" }

            try await withRunningApp(app: app, hostname: "127.0.0.1") { port in
                // Force the client to HTTP/1.1: enabling HTTP/2 on the server must not break H1 clients.
                try await withTLSClient(trustingOnly: credentials.nioCertificate, httpVersion: .http1Only) { client in
                    let response = try await client.execute(
                        HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                        timeout: .seconds(10)
                    )
                    #expect(response.status == .ok)
                    #expect(response.version == .http1_1)
                    #expect(try await response.body.collect(upTo: 1024).string == "world")
                }
            }
        }
    }

    @Test("Server serves over HTTP/2 when negotiated", .timeLimit(.minutes(1)))
    func testServesOverHTTP2() async throws {
        try await withApp { app in
            let credentials = try TestCredentials.localhost()
            app.serverConfiguration.tlsConfiguration = .inMemory(
                certificateChain: [credentials.certificate],
                privateKey: credentials.privateKey
            )
            app.serverConfiguration.httpVersions = [.http1_1, .http2(config: .defaults)]
            app.get("hello") { _ in "world" }

            try await withRunningApp(app: app, hostname: "127.0.0.1") { port in
                // The client defaults to `.automatic`, advertising both h2 and http/1.1 over ALPN.
                // The server offers h2, so the negotiated response should come back over HTTP/2.
                try await withTLSClient(trustingOnly: credentials.nioCertificate) { client in
                    let response = try await client.execute(
                        HTTPClientRequest(url: "https://127.0.0.1:\(port)/hello"),
                        timeout: .seconds(10)
                    )
                    #expect(response.status == .ok)
                    #expect(response.version == .http2)
                    #expect(try await response.body.collect(upTo: 1024).string == "world")
                }
            }
        }
    }

}

// MARK: - Helpers

/// The long-lived self-signed certificate used by the TLS tests.
///
/// `CN=localhost`, with `DNS:localhost` and `IP:127.0.0.1` subject alternative names, valid until
/// 2126. The SANs are what allow the tests to use full hostname verification rather than weakening
/// the client; the older `expired.crt` fixture has no SANs and expired in 2022.
private struct TestCredentials {
    let certificatePath: String
    let privateKeyPath: String
    let certificate: Certificate
    let privateKey: Certificate.PrivateKey
    let nioCertificate: NIOSSLCertificate

    static func localhost() throws -> Self {
        let certificateURL = try #require(Bundle.module.url(forResource: "localhost", withExtension: "crt"))
        let privateKeyURL = try #require(Bundle.module.url(forResource: "localhost", withExtension: "key"))
        let certificatePEM = try String(contentsOf: certificateURL, encoding: .utf8)
        let privateKeyPEM = try String(contentsOf: privateKeyURL, encoding: .utf8)

        return Self(
            certificatePath: certificateURL.path,
            privateKeyPath: privateKeyURL.path,
            certificate: try Certificate(pemEncoded: certificatePEM),
            privateKey: try Certificate.PrivateKey(pemEncoded: privateKeyPEM),
            nioCertificate: try NIOSSLCertificate(bytes: Array(certificatePEM.utf8), format: .pem)
        )
    }
}

/// Generate a self-signed localhost certificate with SANs for hostname verification.
private struct SelfSignedCredentials {
    let certificatePEM: String
    let privateKeyPEM: String
    let nioCertificate: NIOSSLCertificate

    static func generate() throws -> Self {
        let key = Certificate.PrivateKey(P256.Signing.PrivateKey())
        let name = try DistinguishedName { CommonName("localhost") }
        let certificate = try Certificate(
            version: .v3,
            serialNumber: .init(),
            publicKey: key.publicKey,
            notValidBefore: Date().addingTimeInterval(-3600),
            notValidAfter: Date().addingTimeInterval(3600),
            issuer: name,
            subject: name,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions {
                SubjectAlternativeNames([
                    .dnsName("localhost"),
                    .ipAddress(ASN1OctetString(contentBytes: [127, 0, 0, 1])),
                ])
            },
            issuerPrivateKey: key
        )
        let certificatePEM = try certificate.serializeAsPEM().pemString
        return Self(
            certificatePEM: certificatePEM,
            privateKeyPEM: try key.serializeAsPEM().pemString,
            nioCertificate: try NIOSSLCertificate(bytes: Array(certificatePEM.utf8), format: .pem)
        )
    }
}

private func withTLSClient<T>(
    trustingOnly trustedCertificate: NIOSSLCertificate? = nil,
    verification: CertificateVerification = .fullVerification,
    httpVersion: HTTPClient.Configuration.HTTPVersion = .automatic,
    _ body: (HTTPClient) async throws -> T
) async throws -> T {
    var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
    if let trustedCertificate {
        tlsConfiguration.trustRoots = .certificates([trustedCertificate])
    }
    tlsConfiguration.certificateVerification = verification

    var clientConfiguration = HTTPClient.Configuration()
    clientConfiguration.tlsConfiguration = tlsConfiguration
    clientConfiguration.httpVersion = httpVersion

    let client = HTTPClient(
        eventLoopGroup: MultiThreadedEventLoopGroup.singleton,
        configuration: clientConfiguration
    )
    do {
        let result = try await body(client)
        try await client.shutdown()
        return result
    } catch {
        try? await client.shutdown()
        throw error
    }
}
