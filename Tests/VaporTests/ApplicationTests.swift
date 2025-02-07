import Vapor
import XCTVapor
import AsyncHTTPClient
import XCTest
import NIOCore
import NIOEmbedded
import NIOConcurrencyHelpers

final class ApplicationTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application(.testing)
    }

    override func tearDown() async throws {
        try await app.shutdown()
    }

    func testApplicationStop() async throws {
        app.environment.arguments = ["serve"]
        app.http.server.configuration.port = 0
        try await app.startup()
        guard let running = app.running else {
            XCTFail("app started without setting 'running'")
            return
        }
        running.stop()
        try await running.onStop.get()
    }
    
    func testLifecycleHandler() async throws {
        final class Foo: LifecycleHandler {
            let willBootFlag: NIOLockedValueBox<Bool>
            let didBootFlag: NIOLockedValueBox<Bool>
            let shutdownFlag: NIOLockedValueBox<Bool>

            init() {
                self.willBootFlag = .init(false)
                self.didBootFlag = .init(false)
                self.shutdownFlag = .init(false)
            }
            
            func willBoot(_ application: Application) async throws {
                self.willBootFlag.withLockedValue { $0 = true }
            }

            func didBoot(_ application: Application) async throws {
                self.didBootFlag.withLockedValue { $0 = true }
            }

            func shutdown(_ application: Application) async {
                self.shutdownFlag.withLockedValue { $0 = true }
            }
        }
        
        let app = try await Application(.testing)

        let foo = Foo()
        app.lifecycle.use(foo)

        XCTAssertEqual(foo.willBootFlag.withLockedValue({ $0 }), false)
        XCTAssertEqual(foo.didBootFlag.withLockedValue({ $0 }), false)
        XCTAssertEqual(foo.shutdownFlag.withLockedValue({ $0 }), false)

        try await app.boot()

        XCTAssertEqual(foo.willBootFlag.withLockedValue({ $0 }), true)
        XCTAssertEqual(foo.didBootFlag.withLockedValue({ $0 }), true)
        XCTAssertEqual(foo.shutdownFlag.withLockedValue({ $0 }), false)

        try await app.shutdown()

        XCTAssertEqual(foo.willBootFlag.withLockedValue({ $0 }), true)
        XCTAssertEqual(foo.didBootFlag.withLockedValue({ $0 }), true)
        XCTAssertEqual(foo.shutdownFlag.withLockedValue({ $0 }), true)
    }
    
    func testBootDoesNotTriggerLifecycleHandlerMultipleTimes() async throws {
        let app = try await Application(.testing)
        
        final class Handler: LifecycleHandler, Sendable {
            let bootCount = NIOLockedValueBox(0)
            func willBoot(_ application: Application) throws {
                bootCount.withLockedValue { $0 += 1 }
            }
        }
        
        let handler = Handler()
        app.lifecycle.use(handler)
        
        try await app.boot()
        try await app.boot()

        XCTAssertEqual(handler.bootCount.withLockedValue({ $0 }), 1)
        
        try await app.shutdown()
    }

    func testSwiftError() async throws {
        struct Foo: Error { }
        
        app.get("error") { req -> String in
            throw Foo()
        }

        try await app.testable().test(.GET, "/error") { res in
            XCTAssertEqual(res.status, .internalServerError)
        }
    }

    func testAsyncKitExport() throws {
        let eventLoop: EventLoop = EmbeddedEventLoop()
        let a = eventLoop.makePromise(of: Int.self)
        let b = eventLoop.makePromise(of: Int.self)

        let c = [a.futureResult, b.futureResult].flatten(on: eventLoop)

        a.succeed(1)
        b.succeed(2)

        try XCTAssertEqual(c.wait(), [1, 2])
    }

    func testBoilerplate() async throws {
        app.get("hello") { req in
            "Hello, world!"
        }

        app.environment.arguments = ["serve"]
        app.http.server.configuration.port = 0
        try await app.startup()

        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let res = try await app.client.get("http://localhost:\(port)/hello")
        XCTAssertEqual(res.body?.string, "Hello, world!")
    }

    func testAutomaticPortPickingWorks() async {
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0

        app.get("hello") { req in
            "Hello, world!"
        }

        XCTAssertNil(app.http.server.shared.localAddress)

        app.environment.arguments = ["serve"]
        await XCTAssertAsyncNoThrow(try await app.startup())

        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let ip = localAddress.ipAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        XCTAssertEqual("127.0.0.1", ip)
        XCTAssertGreaterThan(port, 0)

        XCTAssertEqual("Hello, world!",
                       try app.client.get("http://localhost:\(port)/hello").wait().body?.string)
    }

    func testConfigurationAddressDetailsReflectedAfterBeingSet() async throws {
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

        app.environment.arguments = ["serve"]
        await XCTAssertAsyncNoThrow(try await app.startup())

        XCTAssertNotNil(app.http.server.shared.localAddress)
        XCTAssertEqual("0.0.0.0", app.http.server.configuration.hostname)
        XCTAssertEqual(app.http.server.shared.localAddress?.port, app.http.server.configuration.port)
        
        guard let localAddress = app.http.server.shared.localAddress,
              localAddress.ipAddress != nil,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }
        let response = try await app.client.get("http://localhost:\(port)/hello")
        let returnedConfig = try response.content.decode(AddressConfig.self)
        XCTAssertEqual(returnedConfig.hostname, "0.0.0.0")
        XCTAssertEqual(returnedConfig.port, port)
    }

    func testConfigurationAddressDetailsReflectedWhenProvidedThroughServeCommand() async throws {
        struct AddressConfig: Content {
            let hostname: String
            let port: Int
        }

        app.get("hello") { req -> AddressConfig in
            let config = AddressConfig(hostname: req.application.http.server.configuration.hostname, port: req.application.http.server.configuration.port)
            return config
        }

        app.environment.arguments = ["vapor", "serve", "--hostname", "0.0.0.0", "--port", "3000"]
        await XCTAssertAsyncNoThrow(try await app.startup())

        XCTAssertNotNil(app.http.server.shared.localAddress)
        XCTAssertEqual("0.0.0.0", app.http.server.configuration.hostname)
        XCTAssertEqual(3000, app.http.server.configuration.port)

        guard let localAddress = app.http.server.shared.localAddress,
              localAddress.ipAddress != nil,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }
        let response = try await app.client.get("http://localhost:\(port)/hello")
        let returnedConfig = try response.content.decode(AddressConfig.self)
        XCTAssertEqual(returnedConfig.hostname, "0.0.0.0")
        XCTAssertEqual(returnedConfig.port, 3000)
    }
}

func XCTAssertAsyncNoThrow<T>(_ expression: @autoclosure () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async {
    do {
        _ = try await expression()
    } catch {
        XCTFail("Unexpected error: \(error)", file: file, line: line)
    }
}
