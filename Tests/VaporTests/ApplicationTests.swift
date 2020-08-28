import Vapor
import XCTVapor
import COperatingSystem
import AsyncHTTPClient

final class ApplicationTests: XCTestCase {
    func testApplicationStop() throws {
        let test = Environment(name: .testing, arguments: ["vapor"])
        let app = Application(test)
        defer { app.shutdown() }
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
        
        let app = Application(.detect(default: .testing))

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
        
        let app = Application(.detect(default: .testing))
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
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

        app.get("hello") { req in
            "Hello, world!"
        }

        try app.start()

        let res = try app.client.get("http://localhost:8080/hello").wait()
        XCTAssertEqual(res.body?.string, "Hello, world!")
    }
}
