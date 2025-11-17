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

    @Test("Test Controller With Multiple Functions")
    func testControllerWithMultipleFunctionsAndDynamicPathParameters() async throws {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @GET("api", "macros", "users")
                func getUsers(req: Request) async throws -> String {
                    return "Users"
                }
            
                @GET("api", "macros", "users", Int.self)
                func getUser(req: Request, userID: Int) async throws -> String {
                    return "User with id \\(userID)" 
                }
            
                @GET("api", "macros", "users", Bool.self)
                func deleteUser(req: Request, delete: Bool) async throws -> String {
                    return "Delete user \\(delete)" 
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
                func getUser(req: Request, userID: Int) async throws -> String {
                    return "User with id \\(userID)" 
                }
            
                func _route_getUser(req: Request) async throws -> Response {
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result = try await getUser(req: req, userID: int0)
                    return try await result.encodeResponse(for: req)
                }
                func deleteUser(req: Request, delete: Bool) async throws -> String {
                    return "Delete user \\(delete)" 
                }
            
                func _route_deleteUser(req: Request) async throws -> Response {
                    let bool0 = try req.parameters.require("bool0", as: Bool.self)
                    let result = try await deleteUser(req: req, delete: bool0)
                    return try await result.encodeResponse(for: req)
                }
            }
            
            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.get("api", "macros", "users") { req async throws in
                    try await self.getUsers(req: req)
                }
                routes.get("api", "macros", ":int0") { req async throws in
                        try await self.getUser(req: req)
                    }
                routes.get("api", "macros", "users", ":bool0") { req async throws in
                        try await self.deleteUser(req: req)
                    }
                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }
}
