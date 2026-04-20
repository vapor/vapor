#if MacroRouting
import Testing
import SwiftSyntaxMacrosGenericTestSupport

#if canImport(VaporMacrosPlugin)

@Suite("Middleware Macro Tests")
struct MiddlewareMacroTests {
    @Test("@Middleware is a no-op marker at expansion time")
    func middlewareMacroIsMarker() {
        assertMacroExpansion(
            """
            @Middleware(LoggingMiddleware())
            func doWork(req: Request) async throws -> String {
                return "ok"
            }
            """,
            expandedSource: """
            func doWork(req: Request) async throws -> String {
                return "ok"
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Per-route @Middleware generates .grouped(...) in Controller boot")
    func perRouteMiddlewareInController() {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @GET("users")
                @Middleware(LoggingMiddleware(), RateLimitMiddleware())
                func list(req: Request) async throws -> String {
                    return "users"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func list(req: Request) async throws -> String {
                    return "users"
                }

                @Sendable func _route_list(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await list(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.grouped(LoggingMiddleware(), RateLimitMiddleware()).get("users") { req async throws -> Response in
                    try await self._route_list(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Type-level @Middleware wraps all routes outside the path group")
    func typeLevelMiddleware() {
        assertMacroExpansion(
            """
            @Controller("api", "users")
            @Middleware(LoggingMiddleware(), AuthGuardMiddleware())
            struct UserController {
                @GET()
                func list(req: Request) async throws -> String {
                    return "users"
                }

                @POST()
                func create(req: Request) async throws -> String {
                    return "created"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func list(req: Request) async throws -> String {
                    return "users"
                }

                @Sendable func _route_list(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await list(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func create(req: Request) async throws -> String {
                    return "created"
                }

                @Sendable func _route_create(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await create(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                let base = routes.grouped(LoggingMiddleware(), AuthGuardMiddleware())
                let group = base.grouped("api", "users")
                group.get { req async throws -> Response in
                    try await self._route_list(req: req)
                }
                group.post { req async throws -> Response in
                    try await self._route_create(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Route @Middleware runs before @AuthMiddleware")
    func routeMiddlewareBeforeAuth() {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @POST("promote", Int.self)
                @Middleware(RateLimitMiddleware())
                @AuthMiddleware(User.self, UserAuthMiddleware())
                func promote(req: Request, user: User, id: Int) async throws -> String {
                    return "promoted"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func promote(req: Request, user: User, id: Int) async throws -> String {
                    return "promoted"
                }

                @Sendable func _route_promote(req: Request) async throws -> Response {
                    let user = try req.auth.require(User.self)
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await promote(req: req, user: user, id: int0)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.grouped(RateLimitMiddleware()).grouped(UserAuthMiddleware()).post("promote", ":int0") { req async throws -> Response in
                    try await self._route_promote(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Stacked @Middleware attributes concatenate in source order")
    func stackedMiddleware() {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @GET("users")
                @Middleware(First())
                @Middleware(Second(), Third())
                func list(req: Request) async throws -> String {
                    return "users"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func list(req: Request) async throws -> String {
                    return "users"
                }

                @Sendable func _route_list(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await list(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.grouped(First(), Second(), Third()).get("users") { req async throws -> Response in
                    try await self._route_list(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Type-level and route-level @Middleware compose correctly")
    func typeAndRouteMiddlewareCompose() {
        assertMacroExpansion(
            """
            @Controller("api")
            @Middleware(GlobalLogging())
            struct UserController {
                @GET("users")
                @Middleware(RouteRateLimit())
                func list(req: Request) async throws -> String {
                    return "users"
                }

                @GET("public")
                func publicRoute(req: Request) async throws -> String {
                    return "public"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func list(req: Request) async throws -> String {
                    return "users"
                }

                @Sendable func _route_list(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await list(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func publicRoute(req: Request) async throws -> String {
                    return "public"
                }

                @Sendable func _route_publicRoute(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await publicRoute(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                let base = routes.grouped(GlobalLogging())
                let group = base.grouped("api")
                group.grouped(RouteRateLimit()).get("users") { req async throws -> Response in
                    try await self._route_list(req: req)
                }
                group.get("public") { req async throws -> Response in
                    try await self._route_publicRoute(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }
}

#endif
#endif
