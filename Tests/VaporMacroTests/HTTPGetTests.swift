import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import VaporMacrosPlugin
import XCTest

let testMacros: [String: any Macro.Type] = [
    "GET": HTTPGetMacro.self,
]

final class HTTPMethodMacroTests: XCTestCase {
    func testGetMacro() {
        assertMacroExpansion(
            """
            @GET("api", "macros", "users")
            func getUsers(req: Request) async throws -> String {
                return "Users"
            }
            """,
            expandedSource: """
            func getUsers(req: Request) async throws -> String {
                return "Users"
            }
            
            func _route_getUsers(req: Request) async throws -> Response {
                let result = try await getUsers(req: req)
                return try await result.encodeResponse(for: req)
            }
            """,
            macros: testMacros
        )
    }

    func testGetMacroWithDynamicPathParameter() {
        assertMacroExpansion(
            """
            @GET("api", "macros", "users", Int.self)
            func getUser(req: Request, id: Int) async throws -> String {
                return "user with id: \\(id)"
            }
            """,
            expandedSource: """
            func getUser(req: Request, id: Int) async throws -> String {
                return "user with id: \\(id)"
            }
            
            func _route_getUser(req: Request) async throws -> Response {
                let int0 = try req.parameters.require("int0", as: Int.self)
                let result = try await getUser(req: req, id: int0)
                return try await result.encodeResponse(for: req)
            }
            """,
            macros: testMacros
        )
    }
}
