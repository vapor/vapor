import Vapor
import XCTVapor
import COperatingSystem
import AsyncHTTPClient
import Baggage

final class ApplicationTests: XCTestCase {
    func testApplicationStop() throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        let app = Application(test)
        defer { app.shutdown() }
        app.environment.arguments = ["serve"]
        try app.start()
        guard let running = app.running else {
            XCTFail("app started without setting 'running'")
            return
        }
        running.stop()
        try running.onStop.wait()
    }

    func testLifecycleHandler() throws {
        final class Foo: LifecycleHandler {
            var willBootFlag: Bool
            var didBootFlag: Bool
            var shutdownFlag: Bool

            init() {
                self.willBootFlag = false
                self.didBootFlag = false
                self.shutdownFlag = false
            }

            func willBoot(_ application: Application) throws {
                self.willBootFlag = true
            }

            func didBoot(_ application: Application) throws {
                self.didBootFlag = true
            }

            func shutdown(_ application: Application) {
                self.shutdownFlag = true
            }
        }
        
        let app = Application(.testing)

        let foo = Foo()
        app.lifecycle.use(foo)

        XCTAssertEqual(foo.willBootFlag, false)
        XCTAssertEqual(foo.didBootFlag, false)
        XCTAssertEqual(foo.shutdownFlag, false)

        try app.boot()

        XCTAssertEqual(foo.willBootFlag, true)
        XCTAssertEqual(foo.didBootFlag, true)
        XCTAssertEqual(foo.shutdownFlag, false)

        app.shutdown()

        XCTAssertEqual(foo.willBootFlag, true)
        XCTAssertEqual(foo.didBootFlag, true)
        XCTAssertEqual(foo.shutdownFlag, true)
    }

    func testSwiftError() throws {
        struct Foo: Error { }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.get("error") { req -> String in
            throw Foo()
        }

        try app.testable().test(.GET, "/error") { res in
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

    func testBoilerplate() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("hello") { req in
            "Hello, world!"
        }

        app.environment.arguments = ["serve"]
        try app.start()
        let context = DefaultLoggingContext.topLevel(logger: app.logger)

        let res = try app.client.get("http://localhost:8080/hello", context: context).wait()
        XCTAssertEqual(res.body?.string, "Hello, world!")
    }

    func testAutomaticPortPickingWorks() {
        let app = Application(.testing)
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        defer { app.shutdown() }

        app.get("hello") { req in
            "Hello, world!"
        }

        XCTAssertNil(app.http.server.shared.localAddress)

        XCTAssertNoThrow(try app.start())

        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let ip = localAddress.ipAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        XCTAssertEqual("127.0.0.1", ip)
        XCTAssertGreaterThan(port, 0)

        let context = DefaultLoggingContext.topLevel(logger: app.logger)

        XCTAssertEqual("Hello, world!",
                       try app.client.get("http://localhost:\(port)/hello", context: context).wait().body?.string)
    }
}
