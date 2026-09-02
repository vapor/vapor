#if HTTPClient
import VaporTesting
import Testing
import Vapor
import NIOCore
import RoutingKit
import HTTPTypes

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
                let cache = EndpointCache<Test>(uri: "http://127.0.0.1:\(port)/number", client: app.client)
                do {
                    let test = try await cache.get(
                        using: app.client
                    )
                    #expect(test.number == 0)
                }
                do {
                    let test = try await cache.get(
                        using: app.client
                    )
                    #expect(test.number == 1)
                }
            }
        }
    }

    @Test("Test cache is refreshed when cache age is expired")
    func testEndpointCacheMaxAge() async throws {
        let shortMaxAge = 1
        try await withApp { app in
            let currentActor = CurrentActor()
            struct Test: Content {
                let number: Int
            }

            // Two endpoints rather than one, because the halves of this test want opposite
            // things from a lifetime. A single `maxAge` has to be short enough to expire
            // during the test and long enough to survive two back-to-back requests, and on a
            // loaded machine those two requests alone can outlast it — which is exactly how
            // this test failed in CI, reporting a value that changed while still cached.
            func number(maxAge: Int) -> @Sendable (Request) async throws -> Response {
                { _ in
                    var res = Response()
                    let current = await currentActor.getCurrent()
                    try res.content.encode(Test(number: current))
                    res.headers.cacheControl = .init(maxAge: maxAge)
                    await currentActor.increment()
                    return res
                }
            }
            app.get("cached", use: number(maxAge: 3600))
            app.get("expiring", use: number(maxAge: shortMaxAge))

            try await withRunningApp(app: app) { port in
                // Two reads inside a lifetime nothing can outlast must return the same value.
                let cached = EndpointCache<Test>(uri: "http://127.0.0.1:\(port)/cached", client: app.client)
                let first = try await cached.get(using: app.client).number
                let second = try await cached.get(using: app.client).number
                #expect(first == second, "cached value changed inside its lifetime")

                // Past the lifetime, the next read must go back to the server. Only elapsed
                // time can break this one, and a slow machine only ever adds more of it. The
                // new value is whatever the counter has reached, so assert that it moved
                // rather than pinning a number the timing above could legitimately change.
                let expiring = EndpointCache<Test>(uri: "http://127.0.0.1:\(port)/expiring", client: app.client)
                let before = try await expiring.get(using: app.client).number
                try await Task.sleep(for: .seconds(shortMaxAge + 1))
                let refreshed = try await expiring.get(using: app.client).number
                #expect(refreshed > before, "cache did not refresh after its lifetime expired")
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
                var res = Response()
                let current = await currentActor.getCurrent()
                try res.content.encode(Test(number: current))
                res.headers.cacheControl = .init(maxAge: 10)
                await currentActor.increment()
                try await Task.sleep(for: .seconds(1))
                return res
            }

            try await withRunningApp(app: app) { port in
                let cache = EndpointCache<Test>(uri: "http://127.0.0.1:\(port)/number", client: app.client)
                async let request1 = cache.get(using: app.client)
                async let request2 = cache.get(using: app.client)
                try await Task.sleep(for: .milliseconds(100))
                #expect(try await request1 == request2)
                let current = await currentActor.current
                #expect(current == 1)
            }
        }
    }

    @Test("Test cache retries after a failed request")
    func testEndpointCacheRetriesAfterFailure() async throws {
        try await withApp { app in
            let currentActor = CurrentActor()
            struct Test: Content, Equatable {
                let number: Int
            }

            app.get("number") { req -> Response in
                let current = await currentActor.getCurrent()
                await currentActor.increment()
                guard current > 0 else {
                    return Response(status: .internalServerError)
                }

                let response = Response()
                try response.content.encode(Test(number: current))
                response.headers.cacheControl = .init(maxAge: 10)
                return response
            }

            try await withRunningApp(app: app) { port in
                let cache = EndpointCache<Test>(uri: "http://localhost:\(port)/number")
                let first = try? await cache.get(using: app.client)
                #expect(first == nil)

                let second = try await cache.get(using: app.client)
                #expect(second.number == 1)
                #expect(await currentActor.current == 2)
            }
        }
    }
}
#endif
