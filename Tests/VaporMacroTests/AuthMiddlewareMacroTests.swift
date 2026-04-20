#if MacroRouting
import Testing
import SwiftSyntaxMacrosGenericTestSupport

#if canImport(VaporMacrosPlugin)

@Suite("AuthMiddleware Macro Tests")
struct AuthMiddlewareMacroTests {
    @Test("Test AuthMiddleware with GET route")
    func testAuthMiddlewareWithGet() {
        assertMacroExpansion(
            """
            @GET("api", "users")
            @AuthMiddleware(User.self, UserAuthMiddleware())
            func getUsers(req: Request, user: User) async throws -> String {
                return "Users"
            }
            """,
            expandedSource: """
            func getUsers(req: Request, user: User) async throws -> String {
                return "Users"
            }

            @Sendable func _route_getUsers(req: Request) async throws -> Response {
                let user = try req.auth.require(User.self)
                let result: some ResponseEncodable = try await getUsers(req: req, user: user)
                return try await result.encodeResponse(for: req)
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test AuthMiddleware with path parameters")
    func testAuthMiddlewareWithPathParams() {
        assertMacroExpansion(
            """
            @POST("api", "users", Int.self, "promote")
            @AuthMiddleware(User.self, UserAuthMiddleware(), AdminOnlyMiddleware())
            func promoteUser(req: Request, authenticatedUser: User, id: Int) async throws -> String {
                return "promoted"
            }
            """,
            expandedSource: """
            func promoteUser(req: Request, authenticatedUser: User, id: Int) async throws -> String {
                return "promoted"
            }

            @Sendable func _route_promoteUser(req: Request) async throws -> Response {
                let authenticatedUser = try req.auth.require(User.self)
                let int0 = try req.parameters.require("int0", as: Int.self)
                let result: some ResponseEncodable = try await promoteUser(req: req, authenticatedUser: authenticatedUser, id: int0)
                return try await result.encodeResponse(for: req)
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test AuthMiddleware with auth param after path param")
    func testAuthMiddlewareWithAuthAfterPath() {
        assertMacroExpansion(
            """
            @GET("api", "users", Int.self)
            @AuthMiddleware(User.self, BearerAuthMiddleware())
            func getUser(req: Request, id: Int, user: User) async throws -> String {
                return "user"
            }
            """,
            expandedSource: """
            func getUser(req: Request, id: Int, user: User) async throws -> String {
                return "user"
            }

            @Sendable func _route_getUser(req: Request) async throws -> Response {
                let int0 = try req.parameters.require("int0", as: Int.self)
                let user = try req.auth.require(User.self)
                let result: some ResponseEncodable = try await getUser(req: req, id: int0, user: user)
                return try await result.encodeResponse(for: req)
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test AuthMiddleware with internal and external parameter names")
    func testAuthMiddlewareWithExternalParamName() {
        assertMacroExpansion(
            """
            @GET("api", "profile")
            @AuthMiddleware(User.self, TokenAuthMiddleware())
            func getProfile(req: Request, auth currentUser: User) async throws -> String {
                return "profile"
            }
            """,
            expandedSource: """
            func getProfile(req: Request, auth currentUser: User) async throws -> String {
                return "profile"
            }

            @Sendable func _route_getProfile(req: Request) async throws -> Response {
                let currentUser = try req.auth.require(User.self)
                let result: some ResponseEncodable = try await getProfile(req: req, auth: currentUser)
                return try await result.encodeResponse(for: req)
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test AuthMiddleware with no additional middlewares")
    func testAuthMiddlewareNoMiddlewares() {
        assertMacroExpansion(
            """
            @GET("api", "me")
            @AuthMiddleware(User.self)
            func getMe(req: Request, user: User) async throws -> String {
                return "me"
            }
            """,
            expandedSource: """
            func getMe(req: Request, user: User) async throws -> String {
                return "me"
            }

            @Sendable func _route_getMe(req: Request) async throws -> Response {
                let user = try req.auth.require(User.self)
                let result: some ResponseEncodable = try await getMe(req: req, user: user)
                return try await result.encodeResponse(for: req)
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test AuthMiddleware fails when auth parameter not found")
    func testAuthMiddlewareFailsWhenParamNotFound() {
        assertMacroExpansion(
            """
            @GET("api", "users")
            @AuthMiddleware(User.self, UserAuthMiddleware())
            func getUsers(req: Request) async throws -> String {
                return "Users"
            }
            """,
            expandedSource: """
            func getUsers(req: Request) async throws -> String {
                return "Users"
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "No function parameter of type User found for @AuthMiddleware", line: 1, column: 1)
            ],
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test AuthMiddleware with sync route")
    func testAuthMiddlewareSyncRoute() {
        assertMacroExpansion(
            """
            @POST("api", "action")
            @AuthMiddleware(User.self, TokenAuthMiddleware())
            func doAction(req: Request, user: User) throws -> String {
                return "done"
            }
            """,
            expandedSource: """
            func doAction(req: Request, user: User) throws -> String {
                return "done"
            }

            @Sendable func _route_doAction(req: Request) async throws -> Response {
                let user = try req.auth.require(User.self)
                let result: some ResponseEncodable = try doAction(req: req, user: user)
                return try await result.encodeResponse(for: req)
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test AuthMiddleware in Controller generates grouped middleware")
    func testAuthMiddlewareInController() {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @GET("api", "users")
                @AuthMiddleware(User.self, UserAuthMiddleware(), AdminOnlyMiddleware())
                func getUsers(req: Request, user: User) async throws -> String {
                    return "Users"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func getUsers(req: Request, user: User) async throws -> String {
                    return "Users"
                }

                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let user = try req.auth.require(User.self)
                    let result: some ResponseEncodable = try await getUsers(req: req, user: user)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.grouped(UserAuthMiddleware(), AdminOnlyMiddleware()).get("api", "users") { req async throws -> Response in
                    try await self._route_getUsers(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test AuthMiddleware with optional auth parameter uses req.auth.get")
    func testAuthMiddlewareOptionalAuth() {
        assertMacroExpansion(
            """
            @GET("api", "feed")
            @AuthMiddleware(User.self)
            func getFeed(req: Request, user: User?) async throws -> String {
                return "feed"
            }
            """,
            expandedSource: """
            func getFeed(req: Request, user: User?) async throws -> String {
                return "feed"
            }

            @Sendable func _route_getFeed(req: Request) async throws -> Response {
                let user = req.auth.get(User.self)
                let result: some ResponseEncodable = try await getFeed(req: req, user: user)
                return try await result.encodeResponse(for: req)
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test AuthMiddleware with optional auth in Controller generates grouped middleware")
    func testAuthMiddlewareOptionalAuthInController() {
        assertMacroExpansion(
            """
            @Controller
            struct FeedController {
                @GET("api", "feed")
                @AuthMiddleware(User.self, TokenAuthMiddleware())
                func getFeed(req: Request, user: User?) async throws -> String {
                    return "feed"
                }
            }
            """,
            expandedSource: """
            struct FeedController {
                func getFeed(req: Request, user: User?) async throws -> String {
                    return "feed"
                }

                @Sendable func _route_getFeed(req: Request) async throws -> Response {
                    let user = req.auth.get(User.self)
                    let result: some ResponseEncodable = try await getFeed(req: req, user: user)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension FeedController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.grouped(TokenAuthMiddleware()).get("api", "feed") { req async throws -> Response in
                    try await self._route_getFeed(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test Controller with mixed auth and non-auth routes")
    func testControllerMixedAuthRoutes() {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @GET("api", "public")
                func publicRoute(req: Request) async throws -> String {
                    return "public"
                }

                @POST("api", "admin", Int.self)
                @AuthMiddleware(User.self, AdminMiddleware())
                func adminAction(req: Request, user: User, id: Int) async throws -> String {
                    return "admin"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func publicRoute(req: Request) async throws -> String {
                    return "public"
                }

                @Sendable func _route_publicRoute(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await publicRoute(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func adminAction(req: Request, user: User, id: Int) async throws -> String {
                    return "admin"
                }

                @Sendable func _route_adminAction(req: Request) async throws -> Response {
                    let user = try req.auth.require(User.self)
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await adminAction(req: req, user: user, id: int0)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.get("api", "public") { req async throws -> Response in
                    try await self._route_publicRoute(req: req)
                }
                routes.grouped(AdminMiddleware()).post("api", "admin", ":int0") { req async throws -> Response in
                    try await self._route_adminAction(req: req)
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
