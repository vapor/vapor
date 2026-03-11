import Testing
import SwiftSyntaxMacrosGenericTestSupport

#if canImport(VaporMacrosPlugin)

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
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test sync macro")
    func testSyncRoute() {
        assertMacroExpansion(
            """
            @GET("sync")
            func syncRoute(req: Request) throws -> String {
                return "Users"
            }
            """,
            expandedSource: """
            func syncRoute(req: Request) throws -> String {
                return "Users"
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro with empty path (root route)")
    func testGetMacroWithEmptyPath() {
        assertMacroExpansion(
            """
            @GET
            func getRoot(req: Request) async throws -> String {
                return "Root"
            }
            """,
            expandedSource: """
            func getRoot(req: Request) async throws -> String {
                return "Root"
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro auto-registers inside a function with Application parameter")
    func testGetMacroAutoRegistersInsideFunction() {
        assertMacroExpansion(
            """
            func routes(_ app: Application) throws {
                @GET("api", "macros", "users")
                func getUsers(req: Request) async throws -> String {
                    return "Users"
                }
            }
            """,
            expandedSource: """
            func routes(_ app: Application) throws {
                func getUsers(req: Request) async throws -> String {
                    return "Users"
                }

                let _route_getUsers: Void = {
                    app.on(.get, "api", "macros", "users") { req async throws -> Response in
                        let result: some ResponseEncodable = try await getUsers(req: req)
                        return try await result.encodeResponse(for: req)
                    }
                }()
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro auto-registers with dynamic params inside function")
    func testGetMacroAutoRegistersWithDynamicParams() {
        assertMacroExpansion(
            """
            func routes(_ app: Application) throws {
                @GET("api", "users", Int.self)
                func getUser(req: Request, id: Int) async throws -> String {
                    return "user"
                }
            }
            """,
            expandedSource: """
            func routes(_ app: Application) throws {
                func getUser(req: Request, id: Int) async throws -> String {
                    return "user"
                }

                let _route_getUser: Void = {
                    app.on(.get, "api", "users", ":int0") { req async throws -> Response in
                        let int0 = try req.parameters.require("int0", as: Int.self)
                        let result: some ResponseEncodable = try await getUser(req: req, id: int0)
                        return try await result.encodeResponse(for: req)
                    }
                }()
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test macro fails when missing Request parameter")
    func testGetMacroFailsWhenMissingRequestParameter() {
        assertMacroExpansion(
            """
            @GET("api", "macros", "users", Int.self)
            func getUser(id: Int) async throws -> String {
                return "user with id: \\(userID)"
            }
            """,
            expandedSource: """
            func getUser(id: Int) async throws -> String {
                return "user with id: \\(userID)"
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "The first parameter to the function must be a Request", line: 1, column: 1)
            ],
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test macro fails when missing no parameters")
    func testGetMacroFailsWhenNoParameters() {
        assertMacroExpansion(
            """
            @GET("api", "macros", "users")
            func getUser() async throws -> String {
                return "user with id: \\(userID)"
            }
            """,
            expandedSource: """
            func getUser() async throws -> String {
                return "user with id: \\(userID)"
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "The first parameter to the function must be a Request", line: 1, column: 1)
            ],
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }
}

#endif
