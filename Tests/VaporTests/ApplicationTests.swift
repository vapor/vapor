import Vapor
import AsyncHTTPClient
import NIOCore
import NIOEmbedded
import NIOConcurrencyHelpers
import Testing
import VaporTesting

@Suite("Application Tests")
struct ApplicationTests {
    @Test("Test stopping the application", .disabled())
    func testApplicationStop() async throws {
        try await withApp { app in
            app.environment.arguments = ["serve"]
            app.http.server.configuration.port = 0
            try await app.startup()
            guard let running = app.running else {
                Issue.record("app started without setting 'running'")
                return
            }
            running.stop()
            try await running.onStop.get()
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
            let app = try await Application(.testing)

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

            app.http.server.configuration.port = 0

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await app.startup()
                }

                try await Task.sleep(for: .milliseconds(10))

                let port = try #require(app.sharedNewAddress.withLockedValue({ $0 })?.port)
                let res = try await app.client.get("http://localhost:\(port)/hello")
                #expect(res.body?.string == "Hello, world!")

                try await app.server.shutdown()
            }
        }
    }

    @Test("Test automatic port picking works")
    func testAutomaticPortPickingWorks() async throws {
        try await withApp { app in
            app.http.server.configuration.hostname = "127.0.0.1"
            app.http.server.configuration.port = 0

            app.get("hello") { req in
                "Hello, world!"
            }

            #expect(app.sharedNewAddress.withLockedValue({ $0 }) == nil)

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    app.environment.arguments = ["serve"]
                    await #expect(throws: Never.self) {
                        try await app.startup()
                    }
                }

                try await Task.sleep(for: .milliseconds(10))

                let address = try #require(app.sharedNewAddress.withLockedValue({ $0 }))

                let ip = try #require(address.ipAddress)
                let port = try #require(address.port)
                #expect("127.0.0.1" == ip)
                #expect(port > 0)

                let response = try await app.client.get("http://localhost:\(port)/hello")
                #expect("Hello, world!" == response.body?.string)

                try await app.server.shutdown()
            }
        }
    }

    @Test("Test configuration address details reflected after being set", .disabled())
    func testConfigurationAddressDetailsReflectedAfterBeingSet() async throws {
        try await withApp { app in
            app.http.server.configuration.hostname = "0.0.0.0"
            app.http.server.configuration.port = 0

            struct AddressConfig: Content {
                let hostname: String
                let port: Int
            }

            app.get("hello") { req -> AddressConfig in
                let config = AddressConfig(hostname: req.application.http.server.configuration.hostname, port: req.application.http.server.configuration.port)
                return config
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    app.environment.arguments = ["serve"]
                    await #expect(throws: Never.self) {
                        try await app.startup()
                    }
                }

                try await Task.sleep(for: .milliseconds(10))

                #expect(app.sharedNewAddress.withLockedValue({ $0 }) != nil)
                #expect(app.sharedNewAddress.withLockedValue({ $0 })?.ipAddress == "0.0.0.0")
                #expect(app.sharedNewAddress.withLockedValue({ $0 })?.port == app.http.server.configuration.port)

                let port = try #require(app.sharedNewAddress.withLockedValue({ $0 })?.port)
                let response = try await app.client.get("http://localhost:\(port)/hello")
                let returnedConfig = try await response.content.decode(AddressConfig.self)
                #expect(returnedConfig.hostname == "0.0.0.0")
                #expect(returnedConfig.port == port)

                try await app.server.shutdown()
            }
        }
    }

    @Test("Test Configuration Address Details Reflected When Provided Through Serve Command", .disabled())
    func testConfigurationAddressDetailsReflectedWhenProvidedThroughServeCommand() async throws {
        try await withApp { app in
            struct AddressConfig: Content {
                let hostname: String
                let port: Int
            }

            app.get("hello") { req -> AddressConfig in
                let config = AddressConfig(hostname: req.application.http.server.configuration.hostname, port: req.application.http.server.configuration.port)
                return config
            }

            app.environment.arguments = ["vapor", "serve", "--hostname", "0.0.0.0", "--port", "3000"]
            await #expect(throws: Never.self) {
                try await app.startup()
            }

            #expect(app.http.server.shared.localAddress != nil)
            #expect(app.http.server.configuration.hostname == "0.0.0.0")
            #expect(app.http.server.configuration.port == 3000)

            let port = try #require(app.http.server.shared.localAddress?.port)
            let response = try await app.client.get("http://localhost:\(port)/hello")
            let returnedConfig = try await response.content.decode(AddressConfig.self)
            #expect(returnedConfig.hostname == "0.0.0.0")
            #expect(returnedConfig.port == 3000)
        }
    }
}
