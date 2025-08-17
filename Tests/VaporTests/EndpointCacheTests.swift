import VaporTesting
import Testing
import Vapor
import NIOCore

@Suite("Endpoint Cache Tests")
struct EndpointCacheTests {
    actor CurrentActor {
        var current = 0
        
        func increment() {
            self.current += 1
        }
        
        func getCurrent() -> Int {
            self.current
        }
    }
    
    @Test("Test cache is filled when there is no cache entry yet")
    func endpointCacheNoCache() async throws {
        let currentActor = CurrentActor()
        struct Test: Content {
            let number: Int
        }

        try await withApp { app in
            app.get("number") { req -> Test in
                let current = await currentActor.getCurrent()
                await currentActor.increment()
                return Test(number: current)
            }

            try await withRunningApp(app: app) { port in
                let cache = EndpointCache<Test>(uri: "http://localhost:\(port)/number")
                do {
                    let test = try await cache.get(
                        using: app.client,
                        logger: app.logger
                    )
                    #expect(test.number == 0)
                }
                do {
                    let test = try await cache.get(
                        using: app.client,
                        logger: app.logger
                    )
                    #expect(test.number == 1)
                }
            }
        }
    }

    @Test("Test cache is refreshed when cache age is expired")
    func testEndpointCacheMaxAge() async throws {
        try await withApp { app in
            let currentActor = CurrentActor()
            struct Test: Content {
                let number: Int
            }

            app.get("number") { req -> Response in
                let res = Response()
                let current = await currentActor.getCurrent()
                try res.content.encode(Test(number: current))
                res.headers.cacheControl = .init(maxAge: 1)
                await currentActor.increment()
                return res
            }

            try await withRunningApp(app: app) { port in
                let cache = EndpointCache<Test>(uri: "http://localhost:\(port)/number")
                do {
                    let test = try await cache.get(
                        using: app.client,
                        logger: app.logger
                    )
                    #expect(test.number == 0)
                }
                do {
                    let test = try await cache.get(
                        using: app.client,
                        logger: app.logger
                    )
                    #expect(test.number == 0)
                }
                // wait for expiry
                try await Task.sleep(for: .seconds(1))
                do {
                    let test = try await cache.get(
                        using: app.client,
                        logger: app.logger
                    )
                    #expect(test.number == 1)
                }
            }
        }
    }

    @Test("Test cache only runs one request at once")
    func testEndpointCacheSequential() async throws {
        try await withApp { app in
            let currentActor = CurrentActor()
            struct Test: Content, Equatable {
                let number: Int
            }

            app.get("number") { req -> Response in
                let res = Response()
                let current = await currentActor.getCurrent()
                try res.content.encode(Test(number: current))
                res.headers.cacheControl = .init(maxAge: 10)
                await currentActor.increment()
                try await Task.sleep(for: .seconds(1))
                return res
            }

            try await withRunningApp(app: app) { port in
                let cache = EndpointCache<Test>(uri: "http://localhost:\(port)/number")
                async let request1 = cache.get(using: app.client, logger: app.logger)
                async let request2 = cache.get(using: app.client, logger: app.logger)
                try await Task.sleep(for: .milliseconds(100))
                #expect(try await request1 == request2)
                let current = await currentActor.current
                #expect(current == 1)
            }
        }
    }
}
