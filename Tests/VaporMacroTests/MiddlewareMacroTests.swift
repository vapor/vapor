#if MacroRouting
import Testing
import SwiftSyntaxMacrosGenericTestSupport
import SwiftSyntaxMacroExpansion

#if canImport(VaporMacrosPlugin)
import VaporMacrosPlugin

@Suite("Middleware Macro Tests")
struct MiddlewareMacroTests {
    // The test harness can only register one MacroSpec per name, so we can't
    // exercise the full `@Controller` + `#Middleware` expansion chain in a
    // single unit test - `assertMacroExpansion` would need both the freestanding
    // `Middleware` DeclarationMacro *and* the nested `@GET` peer macro under
    // the same dictionary. These tests cover the freestanding macro and the
    // Controller macro separately; the integration tests exercise the full chain

    @Test("Test #Middleware lifts each inner function to member scope")
    func testFreestandingMiddlewareLiftsFunctions() {
        let macros: [String: MacroSpec] = [
            "Middleware": MacroSpec(type: FreestandingMiddlewareMacro.self),
        ]
        assertMacroExpansion(
            """
            #Middleware(LoggingMiddleware()) {
                @GET("api", "users")
                func getUsers(req: Request) async throws -> String {
                    return "users"
                }

                @POST("api", "users")
                func createUser(req: Request) async throws -> String {
                    return "created"
                }
            }
            """,
            expandedSource: """
            @GET("api", "users")
                func getUsers(req: Request) async throws -> String {
                    return "users"
                }

                @POST("api", "users")
                func createUser(req: Request) async throws -> String {
                    return "created"
                }
            """,
            macroSpecs: macros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test #Middleware lifts inner functions with dynamic path parameters")
    func testFreestandingMiddlewareWithPathParameters() {
        let macros: [String: MacroSpec] = [
            "Middleware": MacroSpec(type: FreestandingMiddlewareMacro.self),
        ]
        assertMacroExpansion(
            """
            #Middleware(LoggingMiddleware()) {
                @GET("api", "users", Int.self)
                func getUser(req: Request, id: Int) async throws -> String {
                    return "user"
                }
            }
            """,
            expandedSource: """
            @GET("api", "users", Int.self)
                func getUser(req: Request, id: Int) async throws -> String {
                    return "user"
                }
            """,
            macroSpecs: macros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test #Middleware flattens nested #AuthMiddleware and prepends @AuthMiddleware")
    func testFreestandingMiddlewareFlattensNestedAuthMiddleware() {
        let macros: [String: MacroSpec] = [
            "Middleware": MacroSpec(type: FreestandingMiddlewareMacro.self),
        ]
        assertMacroExpansion(
            """
            #Middleware(LoggingMiddleware()) {
                @GET("api", "public")
                func publicRoute(req: Request) async throws -> String {
                    return "public"
                }

                #AuthMiddleware(User.self, TokenAuthMiddleware()) {
                    @GET("api", "private")
                    func privateRoute(req: Request, user: User) async throws -> String {
                        return user.name
                    }
                }
            }
            """,
            expandedSource: """
            @GET("api", "public")
                func publicRoute(req: Request) async throws -> String {
                    return "public"
                }
            @AuthMiddleware(User.self, TokenAuthMiddleware())
                    @GET("api", "private")
                    func privateRoute(req: Request, user: User) async throws -> String {
                        return user.name
                    }
            """,
            macroSpecs: macros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test @Controller wires #Middleware grouped routes via routes.grouped")
    func testControllerWithMiddlewareGroup() {
        let macros: [String: MacroSpec] = [
            "Controller": MacroSpec(type: ControllerMacro.self),
        ]
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                #Middleware(LoggingMiddleware()) {
                    @GET("api", "users")
                    func getUsers(req: Request) async throws -> String {
                        return "users"
                    }

                    @POST("api", "users")
                    func createUser(req: Request) async throws -> String {
                        return "created"
                    }
                }
            }
            """,
            expandedSource: """
            struct UserController {
                #Middleware(LoggingMiddleware()) {
                    @GET("api", "users")
                    func getUsers(req: Request) async throws -> String {
                        return "users"
                    }

                    @POST("api", "users")
                    func createUser(req: Request) async throws -> String {
                        return "created"
                    }
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.grouped(LoggingMiddleware()).get("api", "users") { req async throws -> Response in
                    try await self._route_getUsers(req: req)
                }
                routes.grouped(LoggingMiddleware()).post("api", "users") { req async throws -> Response in
                    try await self._route_createUser(req: req)
                }

                }
            }
            """,
            macroSpecs: macros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test @Controller with multiple middlewares in a group")
    func testControllerWithMultipleMiddlewaresInGroup() {
        let macros: [String: MacroSpec] = [
            "Controller": MacroSpec(type: ControllerMacro.self),
        ]
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                #Middleware(LoggingMiddleware(), MetricsMiddleware()) {
                    @GET("api", "users")
                    func getUsers(req: Request) async throws -> String {
                        return "users"
                    }
                }
            }
            """,
            expandedSource: """
            struct UserController {
                #Middleware(LoggingMiddleware(), MetricsMiddleware()) {
                    @GET("api", "users")
                    func getUsers(req: Request) async throws -> String {
                        return "users"
                    }
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.grouped(LoggingMiddleware(), MetricsMiddleware()).get("api", "users") { req async throws -> Response in
                    try await self._route_getUsers(req: req)
                }

                }
            }
            """,
            macroSpecs: macros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test @Controller passes #Middleware routes alongside ungrouped routes")
    func testControllerMixedGroupedAndUngrouped() {
        let macros: [String: MacroSpec] = [
            "Controller": MacroSpec(type: ControllerMacro.self),
        ]
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                #Middleware(LoggingMiddleware()) {
                    @GET("grp")
                    func grouped(req: Request) async throws -> String {
                        return "grouped"
                    }
                }

                @GET("plain")
                func plain(req: Request) async throws -> String {
                    return "plain"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                #Middleware(LoggingMiddleware()) {
                    @GET("grp")
                    func grouped(req: Request) async throws -> String {
                        return "grouped"
                    }
                }

                @GET("plain")
                func plain(req: Request) async throws -> String {
                    return "plain"
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.grouped(LoggingMiddleware()).get("grp") { req async throws -> Response in
                    try await self._route_grouped(req: req)
                }
                routes.get("plain") { req async throws -> Response in
                    try await self._route_plain(req: req)
                }

                }
            }
            """,
            macroSpecs: macros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test @Controller combines outer #Middleware with nested #AuthMiddleware")
    func testControllerNestedMiddlewareAndAuth() {
        let macros: [String: MacroSpec] = [
            "Controller": MacroSpec(type: ControllerMacro.self),
        ]
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                #Middleware(LoggingMiddleware()) {
                    #AuthMiddleware(User.self, TokenAuthMiddleware()) {
                        @GET("api", "me")
                        func me(req: Request, user: User) async throws -> String {
                            return user.name
                        }
                    }
                }
            }
            """,
            expandedSource: """
            struct UserController {
                #Middleware(LoggingMiddleware()) {
                    #AuthMiddleware(User.self, TokenAuthMiddleware()) {
                        @GET("api", "me")
                        func me(req: Request, user: User) async throws -> String {
                            return user.name
                        }
                    }
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.grouped(LoggingMiddleware(), TokenAuthMiddleware()).get("api", "me") { req async throws -> Response in
                    try await self._route_me(req: req)
                }

                }
            }
            """,
            macroSpecs: macros,
            failureHandler: FailureHandler.instance
        )
    }
}

#endif
#endif
