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
