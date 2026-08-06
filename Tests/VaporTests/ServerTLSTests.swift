@testable import Vapor
import VaporTesting
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import NIOPosix
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

    @Test("Plaintext request to a TLS server fails")
    func testPlaintextRequestToTLSServerFails() async throws {
        try await withApp { app in
            let certPath = try #require(Bundle.module.url(forResource: "expired", withExtension: "crt")).path
            let keyPath  = try #require(Bundle.module.url(forResource: "expired", withExtension: "key")).path

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.serverConfiguration.tlsConfiguration = .pemFile(certificateChainPath: certPath, privateKeyPath: keyPath)
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

                // A plaintext HTTP request to a TLS server must fail: the server can't
                // parse the plaintext bytes as a TLS handshake, so the connection is dropped.
                await #expect(throws: (any Error).self) {
                    _ = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/hello"), timeout: .seconds(5)
                    )
                }

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Client verifies the server presents the configured certificate")
    func testServerPresentsConfiguredCertificate() async throws {
        try await withApp { app in
            let certPEM = TLSData.sampleServerCertificatePEM
            let keyPEM = TLSData.sampleServerPrivateKeyPEM
            let cert = try Certificate(pemEncoded: String(decoding: certPEM, as: UTF8.self))
            let key = try Certificate.PrivateKey(pemEncoded: String(decoding: keyPEM, as: UTF8.self))

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.serverConfiguration.tlsConfiguration = .inMemory(certificateChain: [cert], privateKey: key)
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

                // Pin the exact certificate as the client's only trust root. The handshake
                // succeeds *only* if the server presents this certificate, which verifies the
                // server is serving the cert we configured. Hostname verification is skipped
                // because we connect via 127.0.0.1.
                var tls = TLSConfiguration.makeClientConfiguration()
                tls.trustRoots = .certificates([try NIOSSLCertificate(bytes: certPEM, format: .pem)])
                tls.certificateVerification = .noHostnameVerification
                var cfg = HTTPClient.Configuration()
                cfg.tlsConfiguration = tls
                // Force the NIOSSL (BoringSSL) transport: on Apple platforms the default
                // Network.framework backend can't express custom trust roots.
                let client = HTTPClient(eventLoopGroup: MultiThreadedEventLoopGroup.singleton, configuration: cfg)
                do {
                    let resp = try await client.execute(.init(url: "https://127.0.0.1:\(port)/hello"), timeout: .seconds(10))
                    #expect(resp.status == .ok)
                    #expect(try await resp.body.collect(upTo: 1024).string == "world")
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
}

/// A long-lived self-signed certificate/key pair (CN=localhost, SAN localhost/127.0.0.1),
/// used to verify TLS handshakes against a known certificate.
enum TLSData {
    static var sampleServerCertificatePEM: [UInt8] {
        Array("""
        -----BEGIN CERTIFICATE-----
        MIICyzCCAbOgAwIBAgIJAIgdvU6dg7RbMA0GCSqGSIb3DQEBCwUAMBQxEjAQBgNV
        BAMMCWxvY2FsaG9zdDAgFw0yNjA4MDYxMjEwMzdaGA8yMTI2MDcxMzEyMTAzN1ow
        FDESMBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
        CgKCAQEAw9Lq4mrLdEyo5d2cYdeZwUYUIfE+wHcws0Ck5+KHBMvv5REjCW8pROtN
        ehKGQVEXSTuY+vmyr5ELLdIRNopozrqzwBt8TT19iiHCgDayEN+hAmqh6lwVNPSK
        woIXUlwIhdct5EVVgy5q04GM9UVhvXP8Yc1pEIuJrCjFTUHe/wVTfgpVETraFd6R
        pfE10z+a3d8bfMcjpiBQ29kNj6i8k4dY48FMJplpDUd0/GNlmY2pr4oBn0+gpeir
        beFDbR8qY3/YNY8nmgNNUaay/cGIb+JfgkhISWMRNKHZX8/18mcavzCt7EMPjXAG
        XLMDHDnZ/sjiHSq7nyXsjIdflegDbwIDAQABox4wHDAaBgNVHREEEzARgglsb2Nh
        bGhvc3SHBH8AAAEwDQYJKoZIhvcNAQELBQADggEBAJKk6hfhniF0LPkEsR7FkOru
        aV/Gkg/WI2M6L9vxX6mxb9r2H83jMpJs83sgLwPlU561mYmRWkhkhYuMyAFhqXP9
        2JXddwaeWoFDSAIkpY4DIGYY+f+m9kbBT0/5+GriY21DAtieF3gym/8/jErmkdkp
        zcm2qR1Rmr/7gMXpDgGYRq7I/VX59FpgWRr/ZhJoMwAek78zsuE73WND0ngGVnrx
        VRqSE8F3bXcoT2AGEqDIeuaIK7kCTkyb1T8+SYZDDnujzBqryFse2/wmef0Psx7l
        38inB5NJyQcA96buY7peirANNlow2R2HDbEG2W6c/XuEuH1Nb/fTo1PrL2pkNH0=
        -----END CERTIFICATE-----
        """.utf8)
    }

    static var sampleServerPrivateKeyPEM: [UInt8] {
        Array("""
        -----BEGIN PRIVATE KEY-----
        MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDD0uriast0TKjl
        3Zxh15nBRhQh8T7AdzCzQKTn4ocEy+/lESMJbylE6016EoZBURdJO5j6+bKvkQst
        0hE2imjOurPAG3xNPX2KIcKANrIQ36ECaqHqXBU09IrCghdSXAiF1y3kRVWDLmrT
        gYz1RWG9c/xhzWkQi4msKMVNQd7/BVN+ClUROtoV3pGl8TXTP5rd3xt8xyOmIFDb
        2Q2PqLyTh1jjwUwmmWkNR3T8Y2WZjamvigGfT6Cl6Ktt4UNtHypjf9g1jyeaA01R
        prL9wYhv4l+CSEhJYxE0odlfz/XyZxq/MK3sQw+NcAZcswMcOdn+yOIdKrufJeyM
        h1+V6ANvAgMBAAECggEALW0pRdrmVZVO/Pv6wgvExDwggXs4Rmef6YVOe+hlz+wL
        O4VNLmwWE8HOGEph0JciIr/rjhUMqYOpJzj6+z8CbyqKdj8qB7UDAV8xgpKtnhJy
        hF/+LaKs3Lr50YNiK53j8EBpifG3k5XZ/DSqYV91/AADBSEkhU0JY+GVW4WzWE8Y
        7oriPBuJWWp1ZYJBBTHE6Rie0m9SY82XaRzhpQ4AxvbVZZEbqG1rWKfnvVmCXi1+
        QcvtF30XXcEXAttvT8hJ/yfayyVbk4ZwyG118Na4kgpL+jUPFGAKw/wYVWYHH3Xf
        nf1L5ussLNLwxzHSC9G6aSdYoaWHaezSyX0c0pEOEQKBgQDthbmkiEGdaxqUQ3pq
        o0TgIl8vl9xkP94eUhgH+tfReca8Gv/o8zIkL6YHk7bqoCPyib2oQfAwXN7vkMql
        l1lP2HfI2yluAxp3f+j9dGnXuSm7UWM7tAtBWW7335gZnJEqeKrUC93g5t9Yn8nu
        eZ3qqwCfJH4m3qpRpmGwX/GHiQKBgQDTDsOvdR/f0Z2q+eatsfYlwxF13skFxEDD
        NH6L3yX9n7HSaLLRc746cPc23SBnPpbJF8kIofQ+0Mjbo6kccTOYgr/SjFsA2mp4
        yYlVlYXOCLp1rH2jKlBMqjNDRn0gbFDGs+0GLP5c8MWPI7wd8/6oIoht7V9kHSSF
        DcmSL6Z9NwKBgQCjHdXqv0RIZjhfn6OfPjbbsd8qoSDSm+XfbsNgH409J2Mq5WPf
        x7wki7B6vZ+9q3JkauGbfoUDwZO8c/QnGjRUmDVS8+eUzH7NmEMaZGsXoeqd4HvE
        kZW1MET750reM96hizLN4sRiYkr54upbYpvnf74yjG4yJXJUFm46IPmO+QKBgGtx
        gbcJph9X468NpxxXk1pn8rSRpL51yQ5W4/EquXli2bCmshmklXvE1GUurvdASpy2
        qhXl9KQhv47owweCrWR/c02pPA60Ii25U1upUcOwd9O96vusZ9KPdqdR9BMUcQ6m
        vAw/zYHc5IXZCEQrWUGYyuFDTSN3HodJnIr6DQSDAoGBANvnhftUu+BOzhiUr2MR
        vAOVSrZGzIAtTH05khSr/0Kwa/tM6Un766Aw93gk9ZfAc2HeM7IIounP8HvZ3zlU
        3iM8Z2cIvFWtZIdqADcEu3i3npmQebb8nsiFkMhtR7ZWIJc4qcUj4Wzeb9m7DG0r
        w/d5hL5sGMziFjZaEjPCElkp
        -----END PRIVATE KEY-----
        """.utf8)
    }
}
