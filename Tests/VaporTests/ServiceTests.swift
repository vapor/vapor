import XCTVapor
import XCTest
import Vapor
import NIOCore

final class ServiceTests: XCTestCase {
    func testReadOnly() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("test") { req in
            req.readOnly.foos()
        }

        try app.test(.GET, "test") { res in
            XCTAssertEqual(res.status, .ok)
            try XCTAssertEqual(res.content.decode([String].self), ["foo"])
        }
    }

    func testWritable() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.writable = .init(apiKey: "foo")
        XCTAssertEqual(app.writable?.apiKey, "foo")
    }

    func testLifecycle() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
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
        let app = Application(.testing)
        defer { app.shutdown() }

        app.sync.withLock {
            // Do something.
        }

        struct TestKey: LockKey { }

        let test = app.locks.lock(for: TestKey.self)
        test.withLock {
            // Do something.
        }
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
