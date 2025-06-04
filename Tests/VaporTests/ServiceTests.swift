import Logging
import Vapor
import NIOCore
import Testing
import VaporTesting

@Suite("Service Tests")
struct ServiceTests {
    @Test("Test Read Only")
    func testReadOnly() async throws {
        try await withApp { app in
            app.get("test") { req in
                try await req.readOnly.foos()
            }

            try await app.testing().test(.get, "test") { res throws in
                #expect(res.status == .ok)
                #expect(try await res.content.decode([String].self) == ["foo"])
            }
        }
    }

    @Test("Test Writable")
    func testWritable() async throws {
        try await withApp { app in
            app.writable = .init(apiKey: "foo")
            #expect(app.writable?.apiKey == "foo")
        }
    }

    @Test("Test Locks")
    func testLocks() async throws {
        try await withApp { app in
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

    @Test("Test Service Helpers")
    func testServiceHelpers() async throws {
        try await withApp { app in
            let testString = "This is a test - \(Int.random())"
            let myFakeService = MyTestService(cannedResponse: testString, eventLoop: app.eventLoopGroup.next(), logger: app.logger)

            app.services.myService.use { _ in
                myFakeService
            }

            app.get("myService") { req -> String in
                let thing = req.services.myService.doSomething()
                return thing
            }

            try await app.testing().test(.get, "myService", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(res.body.string == testString)
            })
        }
    }

    @Test("Test Repeated Access Causes No Stackoverflow")
    func testRepeatedAccessCausesNoStackOverflow() async throws {
        try await withApp { app in
            let myFakeService = MyTestService(cannedResponse: "", eventLoop: app.eventLoopGroup.next(), logger: app.logger)
            app.services.myService.use { _ in myFakeService }
            try await app.eventLoopGroup.next()
                .future()
                .map {
                    // ~6.7k iterations should already be sufficient, but even with this many iterations, the test still
                    // run quickly enough, and we would detect potential regressions even for larger stack sizes.
                    for _ in 1...100_000 {
                        _ = app.services.myService.service
                    }
                }
                .get()
        }
    }
}

protocol MyService {
    func `for`(_ request: Request) -> any MyService
    func doSomething() -> String
}

extension Application.Services {
    var myService: Application.Service<any MyService> {
        .init(application: self.application)
    }
}

extension Request.Services {
    var myService: any MyService {
        self.request.application.services.myService.service.for(request)
    }
}

struct MyTestService: MyService {
    let cannedResponse: String
    let eventLoop: any EventLoop
    let logger: Logger
    
    func `for`(_ request: Vapor.Request) -> any MyService {
        return MyTestService(cannedResponse: self.cannedResponse, eventLoop: request.eventLoop, logger: request.logger)
    }
    
    func doSomething() -> String {
        return cannedResponse
    }
}

private struct ReadOnly {
    let client: any Client

    func foos() async throws -> [String] {
        ["foo"]
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
