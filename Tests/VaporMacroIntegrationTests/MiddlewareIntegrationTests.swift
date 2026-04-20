#if MacroRouting
import Testing
import Vapor
import VaporTesting
import VaporMacros
import HTTPTypes
import RoutingKit
import NIOConcurrencyHelpers

@Suite("Middleware Macro Integration Tests")
struct MiddlewareIntegrationTests {

    @Test("Per-route @Middleware runs before the handler")
    func perRouteMiddlewareRuns() async throws {
        try await withApp { app in
            try await app.register(collection: PerRouteMiddlewareController())

            try await app.testing().test(.get, "/per-route") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "ok")
                #expect(res.headers[.middlewareOrder] == "tag-A")
            }
        }
    }

    @Test("Type-level @Middleware runs for every route in the controller")
    func typeLevelMiddlewareRuns() async throws {
        try await withApp { app in
            try await app.register(collection: TypeMiddlewareController())

            try await app.testing().test(.get, "/type/first") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "first")
                #expect(res.headers[.middlewareOrder] == "global")
            }

            try await app.testing().test(.get, "/type/second") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "second")
                #expect(res.headers[.middlewareOrder] == "global")
            }
        }
    }

    @Test("Route-level @Middleware runs before @AuthMiddleware")
    func routeMiddlewareRunsBeforeAuth() async throws {
        try await withApp { app in
            try await app.register(collection: AuthOrderController())

            try await app.testing().test(
                .get,
                "/auth/order",
                headers: [.authorization: "Bearer token"]
            ) { res in
                #expect(res.status == .ok)
                // Middleware appends to the header in chain order. Route middleware is entered
                // first (before auth), so "route" must precede "auth".
                let chain = res.headers[.middlewareOrder] ?? ""
                #expect(chain == "route,auth")
            }
        }
    }

    @Test("Type-level + per-route @Middleware compose with correct order")
    func typeAndRouteMiddlewareCompose() async throws {
        try await withApp { app in
            try await app.register(collection: ComposedMiddlewareController())

            try await app.testing().test(.get, "/composed/route") { res in
                #expect(res.status == .ok)
                let chain = res.headers[.middlewareOrder] ?? ""
                // Type middleware is outermost (entered first), then per-route.
                #expect(chain == "type,route")
            }
        }
    }
}

// MARK: - Test middleware

private extension HTTPField.Name {
    static let middlewareOrder = HTTPField.Name("X-Middleware-Order")!
}

/// Prepends `tag` to the `X-Middleware-Order` response header so the final value reads
/// middleware-entry order from left to right (outermost → innermost).
struct TagMiddleware: Middleware {
    let tag: String

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        let response = try await next.respond(to: request)
        let existing = response.headers[.middlewareOrder]
        response.headers[.middlewareOrder] = existing.map { "\(tag),\($0)" } ?? tag
        return response
    }
}

struct MiddlewareTestUser: Authenticatable {
    let name: String
}

struct MiddlewareTestAuthenticator: BearerAuthenticator {
    typealias User = MiddlewareTestUser

    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        if bearer.token == "token" {
            request.auth.login(MiddlewareTestUser(name: "vapor"))
        }
    }
}

// MARK: - Test controllers

@Controller("per-route")
struct PerRouteMiddlewareController {
    @GET()
    @Middleware(TagMiddleware(tag: "tag-A"))
    func route(req: Request) async throws -> String {
        return "ok"
    }
}

@Controller("type")
@Middleware(TagMiddleware(tag: "global"))
struct TypeMiddlewareController {
    @GET("first")
    func first(req: Request) async throws -> String {
        return "first"
    }

    @GET("second")
    func second(req: Request) async throws -> String {
        return "second"
    }
}

@Controller("auth")
struct AuthOrderController {
    @GET("order")
    @Middleware(TagMiddleware(tag: "route"))
    @AuthMiddleware(MiddlewareTestUser.self, MiddlewareTestAuthenticator(), TagMiddleware(tag: "auth"))
    func order(req: Request, user: MiddlewareTestUser) async throws -> String {
        return user.name
    }
}

@Controller("composed")
@Middleware(TagMiddleware(tag: "type"))
struct ComposedMiddlewareController {
    @GET("route")
    @Middleware(TagMiddleware(tag: "route"))
    func handler(req: Request) async throws -> String {
        return "composed"
    }
}
#endif
