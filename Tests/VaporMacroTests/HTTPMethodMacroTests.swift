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

    func testGetMacroWithMultipleDynamicPathParametersOfSameType() {
        assertMacroExpansion(
            """
            @GET("api", "macros", "users", Int.self, Int.self)
            func getUser(req: Request, userID: Int, clientID: Int) async throws -> String {
                return "user with id: \\(id)"
            }
            """,
            expandedSource: """
            func getUser(req: Request, userID: Int, clientID: Int) async throws -> String {
                return "user with id: \\(id)"
            }
            
            func _route_getUser(req: Request) async throws -> Response {
                let int0 = try req.parameters.require("int0", as: Int.self)
                let int1 = try req.parameters.require("int1", as: Int.self)
                let result = try await getUser(req: req, userID: int0, clientID: int1)
                return try await result.encodeResponse(for: req)
            }
            """,
            macros: testMacros
        )
    }

    func testGetMacroWithMultipleDynamicPathParametersOfDifferentTypes() {
        assertMacroExpansion(
            """
            @GET("api", "macros", "users", Int.self, UUID.self)
            func getUser(req: Request, id: Int, uniqueID: UUID) async throws -> String {
                return "user with id: \\(id)"
            }
            """,
            expandedSource: """
            func getUser(req: Request, id: Int, uniqueID: UUID) async throws -> String {
                return "user with id: \\(id)"
            }
            
            func _route_getUser(req: Request) async throws -> Response {
                let int0 = try req.parameters.require("int0", as: Int.self)
                let uuid1 = try req.parameters.require("uuid1", as: UUID.self)
                let result = try await getUser(req: req, id: int0, uniqueID: uuid1)
                return try await result.encodeResponse(for: req)
            }
            """,
            macros: testMacros
        )
    }

    func testGetMacroWithInternalAndExternalParameterNames() {
        assertMacroExpansion(
            """
            @GET("api", "macros", "users", Int.self)
            func getUser(req: Request, id userID: Int) async throws -> String {
                return "user with id: \\(userID)"
            }
            """,
            expandedSource: """
            func getUser(req: Request, id userID: Int) async throws -> String {
                return "user with id: \\(userID)"
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

    func testGetMacroFailsWhenExtraMacroParameter() {
        assertMacroExpansion(
            """
            @GET("api", "macros", "users", Int.self, UUID.self)
            func getUser(req: Request, id: Int) async throws -> String {
                return "user with id: \\(userID)"
            }
            """,
            expandedSource: """
            func getUser(req: Request, id: Int) async throws -> String {
                return "user with id: \\(userID)"
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "The macro defines 2 arguments, but the function has 1", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testGetMacroFailsWhenExtraFunctionParameter() {
        assertMacroExpansion(
            """
            @GET("api", "macros", "users", Int.self)
            func getUser(req: Request, id: Int, uniqueID: UUID) async throws -> String {
                return "user with id: \\(userID)"
            }
            """,
            expandedSource: """
            func getUser(req: Request, id: Int, uniqueID: UUID) async throws -> String {
                return "user with id: \\(userID)"
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "The macro defines 1 arguments, but the function has 2", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
}
