import XCTVapor
import XCTest
import Vapor
import NIOCore

final class ServiceTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testReadOnly() throws {
        app.get("test") { req in
            req.readOnly.foos()
        }

        try app.test(.GET, "test") { res in
            XCTAssertEqual(res.status, .ok)
            try XCTAssertEqual(res.content.decode([String].self), ["foo"])
        }
    }

    func testWritable() throws {
        app.writable = .init(apiKey: "foo")
        XCTAssertEqual(app.writable?.apiKey, "foo")
    }

    func testLifecycle() throws {
        app.http.server.configuration.port = 0

        app.lifecycle.use(Hello())
        app.environment.arguments = ["serve"]
        try app.start()
        app.running?.stop()
    }
    
    func testAsyncLifecycleHandler() async throws {
        let app = try await Application.make(.testing)
        app.http.server.configuration.port = 0
        
        app.lifecycle.use(AsyncHello())
        app.environment.arguments = ["serve"]
        try await app.startup()
        app.running?.stop()
    }

    func testLocks() throws {
        app.sync.withLock {
            // Do something.
        }

        struct TestKey: LockKey { }

        let test = app.locks.lock(for: TestKey.self)
        test.withLock {
            // Do something.
        }
    }
    
    func testServiceHelpers() throws {
        let testString = "This is a test - \(Int.random())"
        let myFakeService = MyTestService(cannedResponse: testString, eventLoop: app.eventLoopGroup.next(), logger: app.logger)
        
        app.services.myService.use { _ in
            myFakeService
        }
        
        app.get("myService") { req -> String in
            let thing = req.services.myService.doSomething()
            return thing
        }
        
        try app.test(.GET, "myService", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, testString)
        })
    }
    
    func testRepeatedAccessCausesNoStackOverflow() throws {
        let myFakeService = MyTestService(cannedResponse: "", eventLoop: app.eventLoopGroup.next(), logger: app.logger)
        app.services.myService.use { _ in myFakeService }
        
        let app = self.app!  // For use inside the sendable closure
        try app.eventLoopGroup.next()
            .future()
            .map {
                // ~6.7k iterations should already be sufficient, but even with this many iterations, the test still
                // run quickly enough, and we would detect potential regressions even for larger stack sizes.
                for _ in 1...100_000 {
                    _ = app.services.myService.service
                }
            }
            .wait()
    }
}

protocol MyService {
    func `for`(_ request: Request) -> MyService
    func doSomething() -> String
}

extension Application.Services {
    var myService: Application.Service<MyService> {
        .init(application: self.application)
    }
}

extension Request.Services {
    var myService: MyService {
        self.request.application.services.myService.service.for(request)
    }
}

struct MyTestService: MyService {
    let cannedResponse: String
    let eventLoop: EventLoop
    let logger: Logger
    
    func `for`(_ request: Vapor.Request) -> MyService {
        return MyTestService(cannedResponse: self.cannedResponse, eventLoop: request.eventLoop, logger: request.logger)
    }
    
    func doSomething() -> String {
        return cannedResponse
    }
}

private struct ReadOnly {
    let client: Client

    func foos() -> EventLoopFuture<[String]> {
        self.client.eventLoop.makeSucceededFuture(["foo"])
    }
}

private extension Request {
    var readOnly: ReadOnly {
        .init(client: self.client)
    }
}

private struct Writable {
    var apiKey: String
}

private extension Application {
    private struct WritableKey: StorageKey {
        typealias Value = Writable
    }
    var writable: Writable? {
        get {
            self.storage[WritableKey.self]
        }
        set {
            self.storage[WritableKey.self] = newValue
        }
    }
}


private struct Hello: LifecycleHandler {
    func willBoot(_ app: Application) throws {
        app.logger.info("Hello!")
    }
}

private struct AsyncHello: LifecycleHandler {
    func willBootAsync(_ app: Application) async throws {
        app.logger.info("Hello!")
    }
}
