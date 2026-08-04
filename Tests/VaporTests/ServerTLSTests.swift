@testable import Vapor
import VaporTesting
import AsyncHTTPClient
import NIOCore
import NIOSSL
import ServiceLifecycle
import Logging
import Testing
import Foundation
import X509
import SwiftASN1
import RoutingKit

@Suite("Server TLS Tests")
struct ServerTLSTests {

    @Test("tlsConfiguration defaults to nil and is settable")
    func testTLSConfigurationProperty() {
        var config = ServerConfiguration(address: .hostname("localhost", port: 8080))
        #expect(config.tlsConfiguration == nil)
        #expect(config.isTLSEnabled == false)
        config.tlsConfiguration = .pemFile(certificateChainPath: "/x", privateKeyPath: "/y")
        #expect(config.tlsConfiguration != nil)
        #expect(config.isTLSEnabled == true)
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

    @Test("Server serves over TLS with PEM file credentials")
    func testServesOverTLSWithPEMFile() async throws {
        try await withApp { app in
            let certPath = try #require(Bundle.module.url(forResource: "expired", withExtension: "crt")).path
            let keyPath  = try #require(Bundle.module.url(forResource: "expired", withExtension: "key")).path

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.serverConfiguration.tlsConfiguration = .pemFile(certificateChainPath: certPath, privateKeyPath: keyPath)
            app.get("hello") { _ in "world" }

            try await app.boot()
            let group = ServiceGroup(
                configuration: .init(
                    services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                    logger: Logger.current
                )
            )
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                var tls = TLSConfiguration.makeClientConfiguration()
                tls.certificateVerification = .none
                var cfg = HTTPClient.Configuration()
                cfg.tlsConfiguration = tls
                let client = HTTPClient(eventLoopGroupProvider: .singleton, configuration: cfg)
                do {
                    let resp = try await client.execute(.init(url: "https://127.0.0.1:\(port)/hello"), timeout: .seconds(10))
                    let body = try await resp.body.collect(upTo: 1024).string
                    #expect(body == "world")
                    try await client.shutdown()
                } catch {
                    try? await client.shutdown()
                    throw error
                }
                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server serves over TLS with in-memory certificate")
    func testServesOverTLSWithInMemoryCertificate() async throws {
        try await withApp { app in
            let certURL = try #require(Bundle.module.url(forResource: "expired", withExtension: "crt"))
            let keyURL = try #require(Bundle.module.url(forResource: "expired", withExtension: "key"))
            let certs = [try Certificate(pemEncoded: String(contentsOf: certURL, encoding: .utf8))]
            let key = try Certificate.PrivateKey(pemEncoded: String(contentsOf: keyURL, encoding: .utf8))

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.serverConfiguration.tlsConfiguration = .inMemory(certificateChain: certs, privateKey: key)
            app.get("hello") { _ in "world" }

            try await app.boot()
            let group = ServiceGroup(
                configuration: .init(
                    services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                    logger: Logger.current
                )
            )
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                var tls = TLSConfiguration.makeClientConfiguration()
                tls.certificateVerification = .none
                var cfg = HTTPClient.Configuration()
                cfg.tlsConfiguration = tls
                let client = HTTPClient(eventLoopGroupProvider: .singleton, configuration: cfg)
                do {
                    let resp = try await client.execute(.init(url: "https://127.0.0.1:\(port)/hello"), timeout: .seconds(10))
                    let body = try await resp.body.collect(upTo: 1024).string
                    #expect(body == "world")
                    try await client.shutdown()
                } catch {
                    try? await client.shutdown()
                    throw error
                }

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server serves plaintext without TLS configuration")
    func testServesPlaintextWithoutTLSConfiguration() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("hello") { _ in "world" }

            try await app.boot()
            let group = ServiceGroup(configuration: .init(
                services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                let resp = try await HTTPClient.shared.execute(
                    HTTPClientRequest(url: "http://127.0.0.1:\(port)/hello"), timeout: .seconds(10))
                let body = try await resp.body.collect(upTo: 1024).string
                #expect(body == "world")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }
}
