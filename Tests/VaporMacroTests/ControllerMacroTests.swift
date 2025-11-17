import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Controller Macro Tests")
struct ControllerMacroTests {
    @Test("Test Basic Controller")
    func testBasicController() async throws {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @GET("api", "macros", "users")
                func getUsers(req: Request) async throws -> String {
                    return "Users"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func getUsers(req: Request) async throws -> String {
                    return "Users"
                }
            
                func _route_getUsers(req: Request) async throws -> Response {
                    let result = try await getUsers(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }
            
            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.get("api", "macros", "users") { req async throws in
                        try await self.getUsers(req: req)
                    }
                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }
}
