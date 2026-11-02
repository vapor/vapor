#if MacroRouting
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

#if canImport(VaporMacrosPlugin)
import VaporMacrosPlugin

@Suite("Middleware group macros")
struct MiddlewareMacroTests {
    @Test("A key-path auth group expands through every macro role")
    func keyPathGroup() {
        assertMacroExpansion(
            #"""
            @Controller
            struct UserController {
                var authentication: TokenMiddleware { TokenMiddleware() }

                #AuthMiddleware(User.self, using: \Self.authentication) {
                    @GET("me")
                    func me(req: Request, user: User) async throws -> String {
                        user.name
                    }
                }
            }
            """#,
            expandedSource: #"""
                struct UserController {
                    var authentication: TokenMiddleware { TokenMiddleware() }
                            func me(req: Request, user: User) async throws -> String {
                                user.name
                            }

                    @Sendable func _route_me(req: Request) async throws -> Response {
                        let user = try req.auth.require(User.self)
                        let result: some ResponseEncodable = try await me(req: req, user: user)
                        return try await result.encodeResponse(for: req)
                    }
                }

                extension UserController: RouteCollection {
                    func boot(routes: any RoutesBuilder) throws {
                    routes.grouped(self[keyPath: \Self.authentication]).get("me") { req async throws -> Response in
                        try await self._route_me(req: req)
                    }

                    }
                }
                """#,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("A middleware group outside a controller is diagnosed")
    func missingController() {
        assertMacroExpansion(
            """
            #Middleware(LoggingMiddleware()) {
                func index(req: Request) -> String { "ok" }
            }
            """,
            expandedSource: """
                #Middleware(LoggingMiddleware()) {
                    func index(req: Request) -> String { "ok" }
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "Middleware groups must be declared inside a @Controller", line: 1, column: 1)
            ],
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("An auth group outside a controller is diagnosed")
    func authMissingController() {
        assertMacroExpansion(
            """
            #AuthMiddleware(User.self) {
                func index(req: Request, user: User) -> String { "ok" }
            }
            """,
            expandedSource: """
                #AuthMiddleware(User.self) {
                    func index(req: Request, user: User) -> String { "ok" }
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "Middleware groups must be declared inside a @Controller", line: 1, column: 1)
            ],
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }
}
#endif
#endif
