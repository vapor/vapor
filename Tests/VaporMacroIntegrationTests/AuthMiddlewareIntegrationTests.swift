#if MacroRouting
import Testing
import Vapor
import VaporTesting
import VaporMacros
import HTTPTypes
import RoutingKit

@Suite("AuthMiddleware Macro Integration Tests")
struct AuthMiddlewareIntegrationTests {

    @Test("Authenticated route returns user from req.auth.require")
    func authRouteReturnsUser() async throws {
        try await withApp { app in
            try await app.register(collection: AuthTestController())

            try await app.testing().test(
                .get,
                "/api/auth/me",
                headers: [.authorization: "Bearer test-token"]
            ) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
        }
    }

    @Test("Authenticated route without credentials returns 401")
    func authRouteWithoutCredentialsFails() async throws {
        try await withApp { app in
            try await app.register(collection: AuthTestController())

            try await app.testing().test(.get, "/api/auth/me") { res in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test("Authenticated route with path parameter")
    func authRouteWithPathParameter() async throws {
        try await withApp { app in
            try await app.register(collection: AuthTestController())

            try await app.testing().test(
                .post,
                "/api/auth/users/42/promote",
                headers: [.authorization: "Bearer test-token"]
            ) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor promoted 42")
            }
        }
    }

    @Test("Optional auth route works without credentials")
    func optionalAuthRouteAnonymous() async throws {
        try await withApp { app in
            try await app.register(collection: AuthTestController())

            try await app.testing().test(.get, "/api/auth/feed") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "anonymous")
            }
        }
    }

    @Test("Optional auth route resolves user when credentials present")
    func optionalAuthRouteAuthenticated() async throws {
        try await withApp { app in
            try await app.register(collection: AuthTestController())

            try await app.testing().test(
                .get,
                "/api/auth/feed",
                headers: [.authorization: "Bearer test-token"]
            ) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
        }
    }

    @Test("Additional middleware in @AuthMiddleware runs before handler")
    func additionalMiddlewareRuns() async throws {
        try await withApp { app in
            try await app.register(collection: AuthTestController())

            try await app.testing().test(
                .get,
                "/api/auth/admin",
                headers: [.authorization: "Bearer test-token"]
            ) { res in
                #expect(res.status == .forbidden)
            }

            try await app.testing().test(
                .get,
                "/api/auth/admin",
                headers: [.authorization: "Bearer admin-token"]
            ) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Admin")
            }
        }
    }
}

// MARK: - Test fixtures

struct AuthTestUser: Authenticatable, Content {
    let id: Int
    let name: String
    let isAdmin: Bool
}

struct AuthTestTokenMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if let header = request.headers[.authorization] {
            if header == "Bearer test-token" {
                request.auth.login(AuthTestUser(id: 1, name: "Vapor", isAdmin: false))
            } else if header == "Bearer admin-token" {
                request.auth.login(AuthTestUser(id: 2, name: "Admin", isAdmin: true))
            }
        }
        return try await next.respond(to: request)
    }
}

struct AuthTestAdminOnlyMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        guard let user = request.auth.get(AuthTestUser.self), user.isAdmin else {
            throw Abort(.forbidden)
        }
        return try await next.respond(to: request)
    }
}

@Controller
struct AuthTestController {
    @GET("api", "auth", "me")
    @AuthMiddleware(AuthTestUser.self, AuthTestTokenMiddleware())
    func me(req: Request, user: AuthTestUser) async throws -> String {
        return user.name
    }

    @POST("api", "auth", "users", Int.self, "promote")
    @AuthMiddleware(AuthTestUser.self, AuthTestTokenMiddleware())
    func promote(req: Request, user: AuthTestUser, id: Int) async throws -> String {
        return "\(user.name) promoted \(id)"
    }

    @GET("api", "auth", "feed")
    @AuthMiddleware(AuthTestUser.self, AuthTestTokenMiddleware())
    func feed(req: Request, user: AuthTestUser?) async throws -> String {
        return user?.name ?? "anonymous"
    }

    @GET("api", "auth", "admin")
    @AuthMiddleware(AuthTestUser.self, AuthTestTokenMiddleware(), AuthTestAdminOnlyMiddleware())
    func admin(req: Request, user: AuthTestUser) async throws -> String {
        return user.name
    }
}
#endif
