import Vapor
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import NIOEmbedded
import NIOConcurrencyHelpers
import ServiceLifecycle
import Testing
import VaporTesting
import HTTPTypes
import RoutingKit

@Suite("Application Tests")
struct ApplicationTests {
    @Test("Test stopping the application")
    func testApplicationStop() async throws {
        let app = try await Application(.testing, configReader: testConfigReader)
        app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)
        try await app.boot()
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await app.server.run()
            }
            // Poll for address (run() publishes it before blocking on serve)
            while app.sharedNewAddress.withLockedValue({ $0 }) == nil {
                try await Task.sleep(for: .milliseconds(10))
            }
            // Cancel to trigger shutdown
            group.cancelAll()
        }
        try await app.shutdown()
    }

    @Test("Test graceful shutdown drains in-flight requests", .timeLimit(.minutes(1)))
    func testGracefulShutdownDrainsInFlightRequests() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            // Gates to coordinate the in-flight request with the shutdown sequence.
            // Finishing a stream unblocks whoever is awaiting it.
            let (handlerStarted, handlerStartedContinuation) = AsyncStream.makeStream(of: Void.self)
            let (releaseHandler, releaseHandlerContinuation) = AsyncStream.makeStream(of: Void.self)

            app.get("slow") { _ -> String in
                // Signal that the request is now being handled, then block until released.
                handlerStartedContinuation.finish()
                for await _ in releaseHandler {}
                return "drained"
            }

            try await app.boot()

            // Run the server in a real ServiceGroup so we can trigger graceful shutdown explicitly,
            // exercising the path swift-http-server added in PR #55 (graceful-shutdown-aware serve()).
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: [.init(service: app.server, successTerminationBehavior: .gracefullyShutdownGroup)],
                    logger: app.logger
                )
            )

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await serviceGroup.run()
                }

                // Wait for the server to bind and learn its port.
                let address = try await app.server.listeningAddress
                let port = try #require(address.port)

                // Issue a request that will still be in flight when shutdown begins.
                group.addTask {
                    let response = try await HTTPClient.shared.get("http://127.0.0.1:\(port)/slow")
                    let body = try await response.body.collect(upTo: 1024)
                    #expect(response.status == .ok)
                    #expect(body.string == "drained")
                }

                // Once the handler is executing, begin graceful shutdown...
                for await _ in handlerStarted {}
                await serviceGroup.triggerGracefulShutdown()

                // ...then let the in-flight request complete. Graceful shutdown must wait for it
                // to drain rather than dropping the connection.
                releaseHandlerContinuation.finish()

                // Both the in-flight request and the ServiceGroup must finish cleanly.
                try await group.waitForAll()
            }
        }
    }

    @Test("Test application lifecycle")
    func testLifecycleHandler() async throws {
        actor Foo: LifecycleHandler {
            var willBootFlag: Bool
            var didBootFlag: Bool
            var shutdownFlag: Bool

            init() {
                self.willBootFlag = false
                self.didBootFlag = false
                self.shutdownFlag = false
            }

            func willBoot(_ application: Application) async throws {
                self.willBootFlag = true
            }

            func didBoot(_ application: Application) async throws {
                self.didBootFlag = true
            }

            func shutdown(_ application: Application) async {
                self.shutdownFlag = true
            }
        }

        try await withApp { app in
            let app = try await Application(.testing, configReader: testConfigReader)

            let foo = Foo()
            app.lifecycle.use(foo)

            #expect(await foo.willBootFlag == false)
            #expect(await foo.didBootFlag == false)
            #expect(await foo.shutdownFlag == false)

            try await app.boot()

            #expect(await foo.willBootFlag == true)
            #expect(await foo.didBootFlag == true)
            #expect(await foo.shutdownFlag == false)

            try await app.shutdown()

            #expect(await foo.willBootFlag == true)
            #expect(await foo.didBootFlag == true)
            #expect(await foo.shutdownFlag == true)
        }
    }

    @Test("Test Boot Does Not Trigger Lifecycle Handler Multiple Times")
    func testBootDoesNotTriggerLifecycleHandlerMultipleTimes() async throws {
        try await withApp { app in
            actor Handler: LifecycleHandler, Sendable {
                var bootCount = 0
                func willBoot(_ application: Application) throws {
                    bootCount += 1
                }
            }

            let handler = Handler()
            app.lifecycle.use(handler)

            try await app.boot()
            try await app.boot()

            #expect(await handler.bootCount == 1)
        }
    }

    @Test("Test Swift Error")
    func testSwiftError() async throws {
        try await withApp { app in
            struct Foo: Error { }

            app.get("error") { req -> String in
                throw Foo()
            }

            try await app.testing().test(.get, "/error") { res in
                #expect(res.status == .internalServerError)
            }
        }
    }

    @Test("Test Boilerplate")
    func testBoilerplate() async throws {
        try await withApp { app in
            app.get("hello") { req in
                "Hello, world!"
            }

            try await withRunningApp(app: app) { port in
                let response = try await HTTPClient.shared.get("http://localhost:\(port)/hello")
                let body = try await response.body.collect(upTo: 13)
                #expect(body.string == "Hello, world!")
            }
        }
    }

    @Test("Test automatic port picking works")
    func testAutomaticPortPickingWorks() async throws {
        try await withApp { app in
            app.get("hello") { req in
                "Hello, world!"
            }

            #expect(app.sharedNewAddress.withLockedValue({ $0 }) == nil)

            try await withRunningApp(app: app, portToUse: 0) { port in
                let address = try #require(app.sharedNewAddress.withLockedValue({ $0 }))

                let ip = try #require(address.ipAddress)
                #expect(port == address.port)
                #expect("127.0.0.1" == ip || "::1" == ip)
                #expect(port > 0)
                #expect(port != 8080)

                let response = try await HTTPClient.shared.get("http://localhost:\(port)/hello")
                let body = try await response.body.collect(upTo: 13)
                #expect(body.string == "Hello, world!")
            }
        }
    }

    @Test("Test configuration address details reflected after being set")
    func testConfigurationAddressDetailsReflectedAfterBeingSet() async throws {
        try await withApp(configReader: testConfigReader) { app in
            app.serverConfiguration.address = .hostname("0.0.0.0", port: 0)

            struct AddressConfig: Content {
                let hostname: String?
                let port: Int?
            }

            app.get("hello") { req -> AddressConfig in
                let config = AddressConfig(hostname: req.application.sharedNewAddress.withLockedValue({ $0 })?.hostname, port: req.application.sharedNewAddress.withLockedValue({ $0 })?.port)
                return config
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await app.server.run()
                }

                let address = try await app.server.listeningAddress
                #expect(app.sharedNewAddress.withLockedValue({ $0 }) != nil)
                #expect(app.sharedNewAddress.withLockedValue({ $0 })?.ipAddress == "0.0.0.0")
                if case let .hostname(_, port) = app.serverConfiguration.address {
                    #expect(0 == port)
                } else {
                    Issue.record("Bind address not right")
                    group.cancelAll()
                    return
                }

                let port = try #require(address.port)
                #expect(port > 0)
                let response = try await HTTPClient.shared.get("http://localhost:\(port)/hello")
                let body = try await response.body.collect(upTo: 64)
                let returnedConfig = try app.contentConfiguration.requireDecoder(for: .json)
                    .decode(AddressConfig.self, from: body, headers: [:])

                #expect(returnedConfig.hostname == "0.0.0.0")
                #expect(returnedConfig.port == port)

                group.cancelAll()
            }
        }
    }

    @Test("Test Configuration Address Details Reflected When Provided Through Serve Command", .disabled())
    func testConfigurationAddressDetailsReflectedWhenProvidedThroughServeCommand() async throws {
        try await withApp { app in
            struct AddressConfig: Content {
                let hostname: String?
                let port: Int?
            }

            app.get("hello") { req -> AddressConfig in
                let config = AddressConfig(hostname: req.application.serverConfiguration.hostname, port: req.application.serverConfiguration.port)
                return config
            }

            //app.environment.arguments = ["vapor", "serve", "--hostname", "0.0.0.0", "--port", "3000"]
            try await withRunningApp(app: app) { port in
                #expect(app.serverConfiguration.hostname == "0.0.0.0")
                #expect(app.serverConfiguration.port == 3000)
                #expect(port == 3000)

                let response = try await HTTPClient.shared.get("http://localhost:\(port)/hello")
                let body = try await response.body.collect(upTo: 64)
                let returnedConfig = try app.contentConfiguration.requireDecoder(for: .json)
                    .decode(AddressConfig.self, from: body, headers: [:])
                #expect(returnedConfig.hostname == "0.0.0.0")
                #expect(returnedConfig.port == 3000)
            }
        }
    }

    @Test("Routes ASCII Table")
    func routesASCIITable() async throws {
        try await withApp { app in
            app.get("hello") { req in
                "Hello, world!"
            }
            app.post("submit") { req in
                "Submitted!"
            }
            app.get("items", ":id") { req in
                "Item \(req.parameters.get("id") ?? "")"
            }

            let table = app.routesASCIITable()
            let expected = """
            +------+------------+
            | GET  | /hello     |
            +------+------------+
            | POST | /submit    |
            +------+------------+
            | GET  | /items/:id |
            +------+------------+

            """
            #expect(table == expected)
        }
    }
}
