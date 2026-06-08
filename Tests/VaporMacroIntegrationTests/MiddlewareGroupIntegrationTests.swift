#if MacroRouting
import Testing
import Vapor
import VaporTesting
import VaporMacros
import HTTPTypes
import RoutingKit
import NIOConcurrencyHelpers

@Suite("Middleware Group Macro Integration Tests")
struct MiddlewareGroupIntegrationTests {

    @Test("Middleware group route runs its middleware")
    func middlewareRunsForGroupedRoute() async throws {
        try await withApp { app in
            let counter = CallCounter()
            app.storage[MiddlewareCounterKey.self] = counter
            try await app.register(collection: MiddlewareGroupController())

            try await app.testing().test(.get, "/grp/a") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "a")
            }
            #expect(await counter.getCount() == 1)

            try await app.testing().test(.get, "/grp/b") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "b")
            }
            #expect(await counter.getCount() == 2)
        }
    }

    @Test("Middleware group middleware does not run for routes outside the group")
    func middlewareScopedToGroup() async throws {
        try await withApp { app in
            let counter = CallCounter()
            app.storage[MiddlewareCounterKey.self] = counter
            try await app.register(collection: MiddlewareGroupController())

            try await app.testing().test(.get, "/ungrouped") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "plain")
            }
            #expect(await counter.getCount() == 0)
        }
    }

    @Test("Nested #AuthMiddleware inside #Middleware runs both layers")
    func nestedAuthInsideGroupRunsBoth() async throws {
        try await withApp { app in
            let counter = CallCounter()
            app.storage[MiddlewareCounterKey.self] = counter
            try await app.register(collection: NestedMiddlewareController())

            try await app.testing().test(
                .get,
                "/nested/me",
                headers: [.authorization: "Bearer test-token"]
            ) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
            #expect(await counter.getCount() == 1)

            try await app.testing().test(.get, "/nested/me") { res in
                #expect(res.status == .unauthorized)
            }
            #expect(await counter.getCount() == 2)
        }
    }
}

// MARK: - Fixtures

actor CallCounter {
    var count = 0

    func getCount() -> Int {
        return count
    }

    func increment() {
        count += 1
    }
}

struct MiddlewareCounterKey: StorageKey {
    typealias Value = CallCounter
}

struct CountingMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if let counter = request.application.storage[MiddlewareCounterKey.self] {
            await counter.increment()
        }
        return try await next.respond(to: request)
    }
}

@Controller
struct MiddlewareGroupController {
    let counter = CallCounter()
    let middleware = CountingMiddleware()
    #Middleware(middleware) {
        @GET("grp", "a")
        func a(req: Request) async throws -> String {
            return "a"
        }

        @GET("grp", "b")
        func b(req: Request) async throws -> String {
            return "b"
        }
    }

    @GET("ungrouped")
    func ungrouped(req: Request) async throws -> String {
        return "plain"
    }
}

@Controller
struct NestedMiddlewareController {
    #Middleware(CountingMiddleware()) {
        #AuthMiddleware(NestedAuthUser.self, NestedAuthMiddleware()) {
            @GET("nested", "me")
            func me(req: Request, user: NestedAuthUser) async throws -> String {
                return user.name
            }
        }
    }
}

struct NestedAuthUser: Authenticatable, Content {
    let id: Int
    let name: String
}

struct NestedAuthMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if request.headers[.authorization] == "Bearer test-token" {
            request.auth.login(NestedAuthUser(id: 1, name: "Vapor"))
        }
        return try await next.respond(to: request)
    }
}
#endif
