#if MacroRouting
import Testing
import Vapor
import VaporTesting
import VaporMacros
import HTTPTypes
import RoutingKit

@Suite("Controller Macro Integration Tests")
struct ControllerMacroIntegrationTests {

    @Test("GET route returns correct response")
    func controllerGetRoute() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing().test(.get, "/api/test/users") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "users")
            }
        }
    }

    @Test("GET route with path parameter")
    func controllerGetRouteWithPathParameter() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing().test(.get, "/api/test/users/42") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "user with id: 42")
            }
        }
    }

    @Test("POST route")
    func controllerPostRoute() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing().test(.post, "/api/test/sync") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Sync")
            }
        }
    }

    @Test("Custom HTTP method route")
    func controllerCustomHTTPMethod() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing().test(.patch, "/api/test/users/custom") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "custom HTTP method")
            }
        }
    }

    @Test("Custom HTTP method route with path parameter")
    func controllerCustomHTTPMethodWithPathParameter() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing().test(.patch, "/api/test/users/custom/7") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "custom HTTP method with id: 7")
            }
        }
    }

    @Test("Returns 404 for unregistered path")
    func controllerRouteNotFound() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing().test(.get, "/api/test/nonexistent") { res in
                #expect(res.status == .notFound)
            }
        }
    }

    // MARK: - Path Prefix (#3397)

    @Test("Controller with string path prefix routes correctly")
    func controllerStringPathPrefix() async throws {
        try await withApp { app in
            try await app.register(collection: PrefixedController())

            try await app.testing().test(.get, "/api/prefixed/items") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "items")
            }

            try await app.testing().test(.post, "/api/prefixed/items") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "created")
            }
        }
    }

    @Test("Controller with dynamic path prefix extracts prefix param")
    func controllerDynamicPathPrefix() async throws {
        try await withApp { app in
            try await app.register(collection: PrefixedTenantController())

            try await app.testing().test(.get, "/tenants/42/posts") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "posts for tenant 42")
            }
        }
    }

    @Test("Controller with dynamic prefix + dynamic route param extracts both")
    func controllerDynamicPrefixAndRouteParam() async throws {
        try await withApp { app in
            try await app.register(collection: PrefixedTenantController())

            try await app.testing().test(.get, "/tenants/7/posts/welcome") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "post welcome for tenant 7")
            }
        }
    }
}

// MARK: - Prefix test controllers

@Controller("api", "prefixed")
struct PrefixedController {
    @GET("items")
    func list(req: Request) async throws -> String {
        return "items"
    }

    @POST("items")
    func create(req: Request) async throws -> String {
        return "created"
    }
}

@Controller("tenants", Int.self)
struct PrefixedTenantController {
    @GET("posts")
    func listPosts(req: Request, tenantID: Int) async throws -> String {
        return "posts for tenant \(tenantID)"
    }

    @GET("posts", String.self)
    func getPost(req: Request, tenantID: Int, slug: String) async throws -> String {
        return "post \(slug) for tenant \(tenantID)"
    }
}

// MARK: - Test Controller

@Controller
struct TestUserController {
    @GET("api", "test", "users")
    func getUsers(req: Request) async throws -> String {
        return "users"
    }

    @GET("api", "test", "users", Int.self)
    func getUser(req: Request, id: Int) async throws -> String {
        return "user with id: \(id)"
    }

    @POST("api", "test", "sync")
    func syncRoute(req: Request) throws -> String {
        "Sync"
    }

    @HTTP(.patch, "api", "test", "users", "custom")
    func customHTTPMethod(req: Request) async throws -> String {
        return "custom HTTP method"
    }

    @HTTP(.patch, "api", "test", "users", "custom", Int.self)
    func customHTTPMethodWithPathParameter(req: Request, id: Int) async throws -> String {
        return "custom HTTP method with id: \(id)"
    }
}
#endif
