import AsyncHTTPClient
import Atomics
import HTTPTypes
import Logging
import NIOCore
import NIOHTTP1
import NIOHTTPTypesHTTP1
import RoutingKit
import ServiceLifecycle
import SwiftASN1
import Synchronization
import Testing
import Vapor
import VaporTesting
import X509

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("Server Tests")
struct ServerTests {
    @Suite("Address Configuration Tests")
    struct AddressConfigurationTests {
        @Test("Address, hostname and port stay consistent")
        func testAddressConfigurations() throws {
            // `hostname` and `port` are views over `address`, so every way of setting one has to
            // leave the other two agreeing.
            var configuration = ServerConfiguration()
            #expect(configuration.address == .hostname())
            #expect(configuration.hostname == "127.0.0.1")
            #expect(configuration.port == 8080)

            configuration = ServerConfiguration(address: .hostname("1.2.3.4", port: 123))
            #expect(configuration.hostname == "1.2.3.4")
            #expect(configuration.port == 123)

            configuration = ServerConfiguration(address: .hostname("1.2.3.4"))
            #expect(configuration.address == .hostname("1.2.3.4"))
            #expect(configuration.port == 8080)

            configuration = ServerConfiguration(address: .hostname(port: 123))
            #expect(configuration.hostname == "127.0.0.1")
            #expect(configuration.port == 123)
        }

        @Test("A socket path has no hostname or port")
        func testUnixDomainSocketHasNoHostnameOrPort() throws {
            // Unlike the old configuration, which reported defaults here, these are `nil`: a socket
            // path genuinely doesn't have a hostname or a port.
            var configuration = ServerConfiguration(address: .unixDomainSocket(path: "/path"))
            #expect(configuration.address == .unixDomainSocket(path: "/path"))
            #expect(configuration.hostname == nil)
            #expect(configuration.port == nil)

            // Setting either one converts the address, defaulting the half that wasn't given.
            configuration.hostname = "1.2.3.4"
            #expect(configuration.address == .hostname("1.2.3.4", port: 8080))

            configuration.address = .unixDomainSocket(path: "/path")
            configuration.port = 123
            #expect(configuration.address == .hostname("127.0.0.1", port: 123))
        }

        @Test("Setting hostname or port to nil leaves the address alone")
        func testNilHostnameOrPortIsIgnored() throws {
            // The setters ignore `nil` rather than clearing the address — assigning nil can't
            // leave the server with nothing to bind to.
            var configuration = ServerConfiguration(address: .hostname("1.2.3.4", port: 123))
            configuration.hostname = nil
            configuration.port = nil
            #expect(configuration.address == .hostname("1.2.3.4", port: 123))
        }

        @Test("Changing the server configuration after the application has started traps")
        func testServerConfigurationCannotBeChangedAfterStart() async {
            // TLS, HTTP versions and the bind address are all read once as the server comes up, so
            // a later change would be accepted and never used. This is the value that spent several
            // commits wrapped in a `FreezableType` without being frozen, which is why the freeze is
            // now asked of the application's lifecycle rather than tracked per value.
            await #expect(processExitsWith: .failure) {
                do {
                    try await whileServing { $0.serverConfiguration.port = 8099 }
                } catch {
                    print("setup failed rather than trapping: \(error)")
                }
            }
        }

        @Test("Test Port Override")
        func testPortOverride() async throws {
            try await withApp { app in
                // A port set in configuration is the port it binds — not an ephemeral one, and not
                // the default. Hence a fixed port here rather than 0.
                app.serverConfiguration.port = 8123
                app.get("foo") { _ in "bar" }

                try await app.boot()
                let group = ServiceGroup(
                    configuration: .init(
                        services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                        logger: Logger.current))
                try await withThrowingTaskGroup(of: Void.self) { tg in
                    tg.addTask { try await group.run() }

                    let bound = try await app.server.listeningAddress
                    #expect(bound.port == 8123)

                    let res = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:8123/foo"), timeout: .seconds(15))
                    #expect(res.status == .ok)
                    #expect(try await res.body.collect(upTo: 1 << 20).string == "bar")

                    await group.triggerGracefulShutdown()
                    try await tg.waitForAll()
                }
            }
        }

        @Test("Test Too Large Port", .bug("https://github.com/vapor/vapor/issues/2245"))
        func testTooLargePort() async throws {
            try await withApp { app in
                app.serverConfiguration.address = .hostname("127.0.0.1", port: .max)
                await #expect(throws: SocketAddressError.UnknownHost.self) {
                    try await app.boot()
                    try await app.server.run()
                }
            }
        }

        @Test("Binding a port that is already in use throws addressInUse", .timeLimit(.minutes(1)))
        func testAddressAlreadyInUse() async throws {
            try await withApp { first in
                try await withRunningServer(first) { port in
                    try await withApp { second in
                        second.serverConfiguration.address = .hostname("127.0.0.1", port: port)
                        try await second.boot()
                        await #expect(throws: ServerError.addressInUse(host: "127.0.0.1", port: port)) {
                            try await second.server.run()
                        }
                    }
                }
            }
        }

        @Test("addressInUse names the address, bracketing IPv6 hosts")
        func testAddressInUseDescription() {
            #expect(
                ServerError.addressInUse(host: "127.0.0.1", port: 8080).description
                    == "Cannot start the server: 127.0.0.1:8080 is already in use. Discover the process ID with `lsof -i :8080` to determine what to do with it."
            )
            #expect(
                ServerError.addressInUse(host: "::1", port: 8080).description
                    == "Cannot start the server: [::1]:8080 is already in use. Discover the process ID with `lsof -i :8080` to determine what to do with it."
            )
        }

        /// NIOHTTPServer cannot bind a unix domain socket yet: `NIOHTTPServerAdapter` logs a warning and
        /// falls back to `127.0.0.1:8080` instead. Disabled until it can, so they neither run against the
        /// fallback nor get lost.
        static let unixDomainSocketsUnsupported: Comment =
            "NIOHTTPServer has no unix domain socket support; the adapter falls back to 127.0.0.1:8080"

        @Test(
            "Server serves over a unix domain socket",
            .disabled(AddressConfigurationTests.unixDomainSocketsUnsupported), .timeLimit(.minutes(1)))
        func testStartWithValidSocketFile() async throws {
            try await withApp { app in
                let socketPath = "/tmp/\(UUID().uuidString).vapor.socket"
                app.serverConfiguration.address = .unixDomainSocket(path: socketPath)
                app.get("foo") { _ in "bar" }
                try await app.boot()

                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { try await app.server.run() }
                    let bound = try await app.server.listeningAddress
                    #expect(bound.pathname == socketPath)

                    let url = URI(scheme: .httpUnixDomainSocket, host: socketPath, path: "/foo").string
                    let res = try await HTTPClient.shared.execute(HTTPClientRequest(url: url), timeout: .seconds(10))
                    #expect(res.status == .ok)
                    try #expect(await res.body.collect(upTo: 1 << 20).string == "bar")
                    group.cancelAll()
                }
            }
        }

        @Test(
            "Server startup fails when the socket path is a directory",
            .disabled(AddressConfigurationTests.unixDomainSocketsUnsupported), .timeLimit(.minutes(1)))
        func testStartWithUnsupportedSocketFile() async throws {
            try await withApp { app in
                app.serverConfiguration.address = .unixDomainSocket(path: "/tmp")
                try await app.boot()
                await #expect(throws: (any Error).self) {
                    try await app.server.run()
                }
            }
        }

        @Test(
            "Server startup fails when the socket path's directory does not exist",
            .disabled(AddressConfigurationTests.unixDomainSocketsUnsupported), .timeLimit(.minutes(1)))
        func testStartWithInvalidSocketFilePath() async throws {
            try await withApp { app in
                app.serverConfiguration.address = .unixDomainSocket(path: "/tmp/nonexistent/vapor.socket")
                try await app.boot()
                await #expect(throws: (any Error).self) {
                    try await app.server.run()
                }
            }
        }

        @Test("Test Configuration Has Actual Port After Start")
        func testConfigurationHasActualPortAfterStart() async throws {
            try await withApp { app in
                app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
                try await app.boot()
                let group = ServiceGroup(
                    configuration: .init(
                        services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                        logger: Logger.current))
                try await withThrowingTaskGroup(of: Void.self) { tg in
                    tg.addTask { try await group.run() }

                    // Binding with port 0 picks a port; the bound address has to report the real one.
                    let bound = try await app.server.listeningAddress
                    #expect(bound.port != 0)

                    await group.triggerGracefulShutdown()
                    try await tg.waitForAll()
                }
            }
        }
    }

    @Test("Server answers pipelined requests in request order")
    func testPipelinedRequestsAnswerInOrder() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("sleep", ":ms") { req -> String in
                let ms = try req.parameters.require("ms", as: Int64.self)
                try await Task.sleep(for: .milliseconds(ms))
                return "slept \(ms)ms"
            }

            try await app.boot()
            let group = ServiceGroup(
                configuration: .init(
                    services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                    logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                // Both requests go out before either is answered, and the first is much slower than
                // the second. HTTP/1.1 has no way to say which response belongs to which request, so
                // answering out of order hands the client the wrong body.
                let exchange = try await rawExchange(
                    port: port,
                    rawRequest: """
                        GET /sleep/100 HTTP/1.1\r
                        Host: localhost\r
                        \r
                        GET /sleep/0 HTTP/1.1\r
                        Host: localhost\r
                        \r

                        """,
                    // Read until the second response lands rather than until the socket goes quiet:
                    // the two responses are ~100ms apart by design, and a slow machine can stretch
                    // that past any quiet period, leaving the test reading only the first.
                    until: { $0.contains("slept 0ms") })

                let slow = try #require(exchange.bytes.firstRange(of: "slept 100ms"))
                let fast = try #require(exchange.bytes.firstRange(of: "slept 0ms"))
                #expect(slow.lowerBound < fast.lowerBound, "responses came back out of order")

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server rejects invalid HTTP without breaking")
    func testInvalidHTTPDoesNotBreakServer() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            app.get("ok") { _ in "ok" }

            try await app.boot()
            let group = ServiceGroup(
                configuration: .init(
                    services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                    logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask {
                    try await group.run()
                }
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                let garbage = try await rawExchange(
                    port: port, rawRequest: "TOTALLY not a valid HTTP request\r\n\r\n")
                // Rejecting outright or hanging up are both fine; carrying on as if it parsed is not.
                #expect(garbage.serverClosed || garbage.bytes.contains("400"))

                // And the listener is still healthy for everyone else.
                let ok = try await rawExchange(port: port, path: "/ok")
                #expect(ok.bytes.contains("ok"))

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }

    @Test("Server chunk-frames a streamed response of unknown length")
    func testUnknownLengthStreamedResponseIsChunkFramed() async throws {
        try await withApp { app in
            // A real HTTP client hides framing — it parses the response by the rules the server is
            // supposed to be following — so asserting the wire format needs a socket. Vapor sets
            // `Transfer-Encoding: chunked` for a body with no declared count; the server writes the
            // chunk sizes and the terminating chunk. Covers what `PipelineTests.testEchoHandlers`
            // checked against an `EmbeddedChannel` pipeline that no longer exists.
            app.post("echo") { req -> Response in
                // Bodies are lazy, so ask for it.
                let body = try await req.body.collect() ?? Data()
                return Response(
                    body: .init(stream: { writer in
                        try await writer.write(body)
                    }))
            }

            try await withRunningServer(app) { port in
                let exchange = try await rawExchange(
                    port: port,
                    rawRequest: "POST /echo HTTP/1.1\r\nHost: localhost\r\nContent-Length: 3\r\n\r\nabc",
                    until: { $0.contains("0\r\n\r\n") })

                #expect(exchange.bytes.contains("HTTP/1.1 200 OK"))
                // Unknown length, so chunked rather than a Content-Length.
                #expect(exchange.bytes.lowercased().contains("transfer-encoding: chunked"))
                #expect(!exchange.bytes.lowercased().contains("content-length:"))
                // The body, chunk-framed, then the terminating zero-length chunk.
                #expect(exchange.bytes.contains("3\r\nabc\r\n"))
                #expect(exchange.bytes.hasSuffix("0\r\n\r\n"))
                // Framing was valid, so the connection stays up.
                #expect(!exchange.serverClosed)
            }
        }
    }

    @Test("Server treats a request with no framing headers as having an empty body")
    func testRequestWithNoFramingHeadersHasEmptyBody() async throws {
        try await withApp { app in
            // Neither `Content-Length` nor `Transfer-Encoding`, so the request has no body. The server
            // must treat it as empty and answer rather than wait for bytes that are never coming.
            // AsyncHTTPClient always sends `Content-Length: 0` for a body-less POST, so a client-based
            // test never exercises this. Covers `PipelineTests.testEOFFraming`.
            app.post("count") { req -> String in
                "\(req.body.data?.count ?? 0)"
            }

            try await withRunningServer(app) { port in
                let exchange = try await rawExchange(
                    port: port,
                    rawRequest: "POST /count HTTP/1.1\r\nHost: localhost\r\n\r\n",
                    until: { $0.contains("\r\n\r\n0") })

                #expect(exchange.bytes.contains("HTTP/1.1 200 OK"))
                #expect(exchange.bytes.hasSuffix("0"))
                #expect(!exchange.serverClosed)
            }
        }
    }

    @Test("Server closes with Connection: close when it can't drain the request body")
    func testUndrainableRequestBodyIsAnsweredWithConnectionClose() async throws {
        try await withApp { app in
            // A request rejected without being read leaves its body on the wire. If more is left than
            // `maxDrainBytes`, the connection can't be reused — and the client has to learn that from
            // the response, not from a socket that dies under its still-in-flight upload. Answering
            // with keep-alive framing and then hanging up makes the client fail the request it has
            // already been answered.
            app.routes.defaultMaxBodySize = 1
            // The handler has to *ask* for the body for the limit to bite — that is what lazy
            // collection means. A route that never reads an oversized body now answers normally.
            app.on(.post, "reject") { req -> HTTPResponse.Status in
                _ = try await req.body.collect()
                return .ok
            }

            try await withRunningServer(app) { port in
                let oversized = String(repeating: "a", count: 500_000)
                #expect(oversized.utf8.count > app.serverConfiguration.maxDrainBytes)

                let exchange = try await rawExchange(
                    port: port,
                    rawRequest: """
                        POST /reject HTTP/1.1\r
                        Host: localhost\r
                        Content-Length: \(oversized.utf8.count)\r
                        \r
                        \(oversized)
                        """,
                    until: { $0.contains("\r\n\r\n") })

                #expect(exchange.bytes.contains("HTTP/1.1 413 Payload Too Large"))
                #expect(exchange.bytes.lowercased().contains("connection: close"))
                // Deliberately no assertion on *how* the connection ends. With this much of the body
                // left unread the server's close races the client's remaining writes, so it lands as
                // either a clean FIN or an RST depending on timing — asserting either one is a flake.
                // The header is the contract: the client is told not to reuse the connection.
            }
        }
    }

    @Test("Test Live Server")
    func testLiveServer() async throws {
        try await withApp { app in
            app.routes.get("ping") { req -> String in
                return "123"
            }

            try await app.testing { client in
                let res = try await client.get("/ping")
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "123")
            }
        }
    }

    @Test("Test Custom Server", .timeLimit(.minutes(1)))
    func testCustomServer() async throws {
        let customServer = CustomServer()
        try await withApp(services: .init(server: .provided(customServer))) { app in
            #expect(customServer.didStart.withLock({ $0 }) == false)
            #expect(customServer.didShutdown.withLock({ $0 }) == false)

            await withTaskGroup(of: Void.self) { group in
                group.addTask { try? await app.server.run() }
                await customServer.started.wait()
                #expect(customServer.didStart.withLock({ $0 }) == true)
                #expect(customServer.didShutdown.withLock({ $0 }) == false)
                group.cancelAll()
            }
            #expect(customServer.didShutdown.withLock({ $0 }) == true)
        }
    }

    @Test("Test Multiple Chunk Body")
    func testMultipleChunkBody() async throws {
        try await withApp { app in
            let payload = [UInt8].random(count: 1 << 20)

            app.on(.post, "payload", maxBodySize: "1gb") { req -> HTTPResponse.Status in
                guard let data = try await req.body.collect() else {
                    throw Abort(.internalServerError)
                }
                #expect(payload.count == data.count)
                #expect([UInt8](data) == payload)
                return .ok
            }

            try await app.testing(.running) { client in
                let res = try await client.post("payload") { req in
                    req.body = .init(data: Data(payload))
                }
                #expect(res.status == .ok)
            }
        }
    }

    @Test("Test Missing Body", .bug("https://github.com/vapor/vapor/issues/1786"))
    func testMissingBody() async throws {
        struct User: Content {}

        try await withApp { app in
            app.get("user") { req -> User in
                return try await req.content.decode(User.self)
            }

            try await app.testing { client in
                let res = try await client.get("/user")
                #expect(res.status == .unsupportedMediaType)
            }
        }
    }

    @Test("Test Quiesce Keep Alive Connections", .timeLimit(.minutes(1)))
    func testQuiesceKeepAliveConnections() async throws {
        try await withApp { app in
            app.get("hello") { req in
                "world"
            }

            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
            try await app.boot()
            let group = ServiceGroup(
                configuration: .init(
                    services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                    logger: Logger.current))
            try await withThrowingTaskGroup(of: Void.self) { tg in
                tg.addTask { try await group.run() }
                let port = try #require(try await app.server.listeningAddress.port)

                var request = HTTPClientRequest(url: "http://127.0.0.1:\(port)/hello")
                request.headers.add(name: "connection", value: "keep-alive")
                let response = try await HTTPClient.shared.execute(request, timeout: .seconds(15))
                #expect(response.status == .ok)
                // HTTP/1.1 connections persist by default, so a correct server says nothing rather
                // than sending `Connection: keep-alive` — only `close` needs announcing. What
                // matters is that it doesn't ask to hang up, and that the graceful shutdown below
                // still completes with the connection open.
                #expect(HTTPFields(response.headers, splitCookie: false).connection != .close)

                await group.triggerGracefulShutdown()
                try await tg.waitForAll()
            }
        }
    }
}

final class CustomServer: Server, Sendable {
    let didStart: Mutex<Bool>
    let didShutdown: Mutex<Bool>
    /// Reached once `run()` has been entered, for a test to wait on rather than poll.
    let started = Checkpoint()

    init() {
        self.didStart = .init(false)
        self.didShutdown = .init(false)
    }

    func run() async throws {
        self.didStart.withLock { $0 = true }
        self.started.reach()
        // Block until cancelled
        try await withTaskCancellationHandler {
            try await Task.sleep(for: .seconds(3600))
        } onCancel: {
            self.didShutdown.withLock { $0 = true }
        }
    }

    var listeningAddress: Vapor.SocketAddress {
        get async throws {
            Vapor.SocketAddress(ipAddress: "127.0.0.1", port: 0)!
        }
    }
}

extension ByteBuffer {
    fileprivate init?(base64String: String) {
        guard let decoded = Data(base64Encoded: base64String) else { return nil }
        var buffer = ByteBufferAllocator().buffer(capacity: decoded.count)
        buffer.writeBytes(decoded)
        self = buffer
    }
}
