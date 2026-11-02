#if MacroRouting
import Testing

#if canImport(VaporMacrosPlugin)
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

                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
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

                @Sendable func _route_getUser(req: Request) async throws -> Response {
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await getUser(req: req, id: int0)
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

                @Sendable func _route_getUser(req: Request) async throws -> Response {
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let int1 = try req.parameters.require("int1", as: Int.self)
                    let result: some ResponseEncodable = try await getUser(req: req, userID: int0, clientID: int1)
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

                @Sendable func _route_getUser(req: Request) async throws -> Response {
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let uuid1 = try req.parameters.require("uuid1", as: UUID.self)
                    let result: some ResponseEncodable = try await getUser(req: req, id: int0, uniqueID: uuid1)
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

                @Sendable func _route_getUser(req: Request) async throws -> Response {
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await getUser(req: req, id: int0)
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

                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
                    return try await result.encodeResponse(for: req)
                }
                """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("POST retains a leading typed path parameter")
    func testPostMacroWithLeadingPathParameter() {
        assertMacroExpansion(
            """
            @POST(Int.self, "users")
            func updateUser(req: Request, id: Int) async throws -> String {
                return "updated"
            }
            """,
            expandedSource: """
                func updateUser(req: Request, id: Int) async throws -> String {
                    return "updated"
                }

                @Sendable func _route_updateUser(req: Request) async throws -> Response {
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await updateUser(req: req, id: int0)
                    return try await result.encodeResponse(for: req)
                }
                """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("POST decodes a labeled body type and retains path parameters")
    func testPostMacroWithBodyAndPathParameter() {
        assertMacroExpansion(
            """
            @POST(content: User.self, "users", Int.self)
            func createUser(req: Request, user: User, id: Int) async throws -> String {
                return user.name
            }
            """,
            expandedSource: """
                func createUser(req: Request, user: User, id: Int) async throws -> String {
                    return user.name
                }

                @Sendable func _route_createUser(req: Request) async throws -> Response {
                    let body = try await req.content.decode(User.self)
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await createUser(req: req, user: body, id: int0)
                    return try await result.encodeResponse(for: req)
                }
                """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("POST content requires a response type")
    func testPostMacroWithoutResponseType() {
        assertMacroExpansion(
            """
            @POST(content: User.self, "users")
            func createUser(req: Request, user: User) async throws {
                save(user)
            }
            """,
            expandedSource: """
                func createUser(req: Request, user: User) async throws {
                    save(user)
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@POST handlers with content must declare a non-Void response type", line: 1, column: 1)
            ],
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("POST content rejects an explicit Void response type")
    func testPostMacroWithVoidResponseType() {
        assertMacroExpansion(
            """
            @POST(content: User.self, "users")
            func createUser(req: Request, user: User) async throws -> Void {
                save(user)
            }
            """,
            expandedSource: """
                func createUser(req: Request, user: User) async throws -> Void {
                    save(user)
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@POST handlers with content must declare a non-Void response type", line: 1, column: 1)
            ],
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("POST body type must match the handler")
    func testPostMacroBodyTypeMismatch() {
        assertMacroExpansion(
            """
            @POST(content: User.self, "users")
            func createUser(req: Request, input: Other) async throws -> String {
                return "created"
            }
            """,
            expandedSource: """
                func createUser(req: Request, input: Other) async throws -> String {
                    return "created"
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "The first non-authentication parameter of @POST must have type User", line: 1, column: 1)
            ],
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

                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
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

                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
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

                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
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

                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
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

                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
                    return try await result.encodeResponse(for: req)
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

                @Sendable func _route_syncRoute(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try syncRoute(req: req)
                    return try await result.encodeResponse(for: req)
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

                    let _register_getUsers = app.on(.get, "api", "macros", "users") { req -> Response in
                        let result: some ResponseEncodable = try await getUsers(req: req)
                        return try await result.encodeResponse(for: req)
                    }
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

                    let _register_getUser = app.on(.get, "api", "users", ":int0") { req -> Response in
                        let int0 = try req.parameters.require("int0", as: Int.self)
                        let result: some ResponseEncodable = try await getUser(req: req, id: int0)
                        return try await result.encodeResponse(for: req)
                    }
                }
                """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro auto-registers inside function with RoutesBuilder parameter")
    func testGetMacroAutoRegistersWithRoutesBuilder() {
        assertMacroExpansion(
            """
            func routes(_ routes: some RoutesBuilder) throws {
                @GET("api", "users")
                func getUsers(req: Request) async throws -> String {
                    return "Users"
                }
            }
            """,
            expandedSource: """
                func routes(_ routes: some RoutesBuilder) throws {
                    func getUsers(req: Request) async throws -> String {
                        return "Users"
                    }

                    let _register_getUsers = routes.on(.get, "api", "users") { req -> Response in
                        let result: some ResponseEncodable = try await getUsers(req: req)
                        return try await result.encodeResponse(for: req)
                    }
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

    @Test("Test GET macro with RoutesBuilder passed in")
    func testGetMacroWithRoutesBuilderPassedIn() {
        assertMacroExpansion(
            """
            @GET(on: app, "api", "macros", "users")
            func getUsers(req: Request) async throws -> String {
                return "Users"
            }
            """,
            expandedSource: """
                func getUsers(req: Request) async throws -> String {
                    return "Users"
                }

                let _register_getUsers = app.on(.get, "api", "macros", "users") { req -> Response in
                    let result: some ResponseEncodable = try await getUsers(req: req)
                    return try await result.encodeResponse(for: req)
                }
                """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test GET macro with RoutesBuilder passed in")
    func testGetMacroWithRoutesBuilderPassedInWithDynamicPathParameters() {
        assertMacroExpansion(
            """
            @GET(on: routes, "api", "macros", "users", Int.self)
            func getUsers(req: Request, userID: Int) async throws -> String {
                return "Users"
            }
            """,
            expandedSource: """
                func getUsers(req: Request, userID: Int) async throws -> String {
                    return "Users"
                }

                let _register_getUsers = routes.on(.get, "api", "macros", "users", ":int0") { req -> Response in
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await getUsers(req: req, userID: int0)
                    return try await result.encodeResponse(for: req)
                }
                """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test HTTP Method macro with RoutesBuilder passed in")
    func testHTTPMethodMacroWithRoutesBuilderPassedInWithDynamicPathParameters() {
        assertMacroExpansion(
            """
            @HTTP(on: app, .options, "api", "macros", "users", Int.self)
            func getUsers(req: Request, userID: Int) async throws -> String {
                return "Users"
            }
            """,
            expandedSource: """
                func getUsers(req: Request, userID: Int) async throws -> String {
                    return "Users"
                }

                let _register_getUsers = app.on(.options, "api", "macros", "users", ":int0") { req -> Response in
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await getUsers(req: req, userID: int0)
                    return try await result.encodeResponse(for: req)
                }
                """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }
}

#endif
#endif
