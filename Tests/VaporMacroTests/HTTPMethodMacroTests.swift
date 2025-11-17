import Testing
import SwiftSyntaxMacrosGenericTestSupport

@Suite("HTTP Method Macro Tests")
struct HTTPMethodMacroTests {
    @Test("Test GET macro")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro with dynamic path parameter")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro with multiple dynamic path parameters of same type")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro with multiple dynamic path parameters of different types")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro with internal and external parameter names")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro fails when extra function parameter")
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
                DiagnosticSpec(message: "The @GET macro defines 2 arguments, but the function has 1", line: 1, column: 1)
            ],
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro fails when extra function parameter")
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
                DiagnosticSpec(message: "The @GET macro defines 1 arguments, but the function has 2", line: 1, column: 1)
            ],
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test POST macro")
    func testPostMacro() {
        assertMacroExpansion(
            """
            @POST("api", "macros", "users")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test PUT macro")
    func testPutMacro() {
        assertMacroExpansion(
            """
            @PUT("api", "macros", "users")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test PATCH macro")
    func testPatchMacro() {
        assertMacroExpansion(
            """
            @PATCH("api", "macros", "users")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test DELETE macro")
    func testDeleteMacro() {
        assertMacroExpansion(
            """
            @DELETE("api", "macros", "users")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test HTTP Method macro")
    func testHTTPMethodMacro() {
        assertMacroExpansion(
            """
            @HTTP(.get, "api", "macros", "users")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test HTTP Method macro with fully qualified method")
    func testHTTPMethodMacroFullyQualifiedMethod() {
        assertMacroExpansion(
            """
            @HTTP(HTTPRequest.Method.get, "api", "macros", "users")
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
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }
}
