#if MacroRouting
import SwiftSyntaxMacrosGenericTestSupport
import Testing

#if canImport(VaporMacrosPlugin)

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
            
                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }
            
            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.get("api", "macros", "users") { req async throws -> Response in
                    try await self._route_getUsers(req: req)
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
            
                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func getUser(req: Request, userID: Int) async throws -> String {
                    return "User with id \\(userID)" 
                }
            
                @Sendable func _route_getUser(req: Request) async throws -> Response {
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await getUser(req: req, userID: int0)
                    return try await result.encodeResponse(for: req)
                }
                func deleteUser(req: Request, delete: Bool) async throws -> String {
                    return "Delete user \\(delete)" 
                }
            
                @Sendable func _route_deleteUser(req: Request) async throws -> Response {
                    let bool0 = try req.parameters.require("bool0", as: Bool.self)
                    let result: some ResponseEncodable = try await deleteUser(req: req, delete: bool0)
                    return try await result.encodeResponse(for: req)
                }
            }
            
            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.get("api", "macros", "users") { req async throws -> Response in
                    try await self._route_getUsers(req: req)
                }
                routes.get("api", "macros", "users", ":int0") { req async throws -> Response in
                    try await self._route_getUser(req: req)
                }
                routes.get("api", "macros", "users", ":bool0") { req async throws -> Response in
                    try await self._route_deleteUser(req: req)
                }
            
                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test Controller With Different HTTP Methods")
    func testControllerWithDifferentHTTPMethods() async throws {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @GET("api", "macros", "users")
                func getUsers(req: Request) async throws -> String {
                    return "Users"
                }
            
                @POST("api", "macros", "users")
                func createUser(req: Request) async throws -> String {
                    return "Create Users"
                }
            
                @DELETE("api", "macros", "users")
                func deleteUser(req: Request) async throws -> String {
                    return "Delete Users"
                }
            
                @PATCH("api", "macros", "users")
                func patchUser(req: Request) async throws -> String {
                    return "Patch Users"
                }

                @PUT("api", "macros", "users")
                func putUser(req: Request) async throws -> String {
                    return "Put Users"
                }

                @HTTP(.options, "api", "macros", "users")
                func optionsUser(req: Request) async throws -> String {
                    return "Options Users"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func getUsers(req: Request) async throws -> String {
                    return "Users"
                }
            
                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func createUser(req: Request) async throws -> String {
                    return "Create Users"
                }
            
                @Sendable func _route_createUser(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await createUser(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func deleteUser(req: Request) async throws -> String {
                    return "Delete Users"
                }
            
                @Sendable func _route_deleteUser(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await deleteUser(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func patchUser(req: Request) async throws -> String {
                    return "Patch Users"
                }
            
                @Sendable func _route_patchUser(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await patchUser(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func putUser(req: Request) async throws -> String {
                    return "Put Users"
                }
            
                @Sendable func _route_putUser(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await putUser(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func optionsUser(req: Request) async throws -> String {
                    return "Options Users"
                }
            
                @Sendable func _route_optionsUser(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await optionsUser(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }
            
            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.get("api", "macros", "users") { req async throws -> Response in
                    try await self._route_getUsers(req: req)
                }
                routes.post("api", "macros", "users") { req async throws -> Response in
                    try await self._route_createUser(req: req)
                }
                routes.delete("api", "macros", "users") { req async throws -> Response in
                    try await self._route_deleteUser(req: req)
                }
                routes.patch("api", "macros", "users") { req async throws -> Response in
                    try await self._route_patchUser(req: req)
                }
                routes.put("api", "macros", "users") { req async throws -> Response in
                    try await self._route_putUser(req: req)
                }
                routes.options("api", "macros", "users") { req async throws -> Response in
                    try await self._route_optionsUser(req: req)
                }
            
                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test Controller with Root Route with Brackets")
    func testControllerWithRootRouteBrackets() async throws {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @GET()
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
            
                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }
            
            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.get { req async throws -> Response in
                    try await self._route_getUsers(req: req)
                }
            
                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test Controller with Root Route with No Brackets")
    func testControllerWithRootRouteNoBrackets() async throws {
        assertMacroExpansion(
            """
            @Controller
            struct UserController {
                @GET
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

                @Sendable func _route_getUsers(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await getUsers(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.get { req async throws -> Response in
                    try await self._route_getUsers(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    // MARK: - Path Prefix (#3397)

    @Test("Test Controller with string path prefix")
    func testControllerWithStringPathPrefix() async throws {
        assertMacroExpansion(
            """
            @Controller("api", "users")
            struct UserController {
                @GET()
                func list(req: Request) async throws -> String {
                    return "Users"
                }

                @POST("invite")
                func invite(req: Request) async throws -> String {
                    return "Invited"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func list(req: Request) async throws -> String {
                    return "Users"
                }

                @Sendable func _route_list(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await list(req: req)
                    return try await result.encodeResponse(for: req)
                }
                func invite(req: Request) async throws -> String {
                    return "Invited"
                }

                @Sendable func _route_invite(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await invite(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                let group = routes.grouped("api", "users")
                group.get { req async throws -> Response in
                    try await self._route_list(req: req)
                }
                group.post("invite") { req async throws -> Response in
                    try await self._route_invite(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test Controller with dynamic path prefix")
    func testControllerWithDynamicPathPrefix() async throws {
        assertMacroExpansion(
            """
            @Controller("users", Int.self)
            struct UserController {
                @GET("posts")
                func listPosts(req: Request, userID: Int) async throws -> String {
                    return "posts for user \\(userID)"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func listPosts(req: Request, userID: Int) async throws -> String {
                    return "posts for user \\(userID)"
                }

                @Sendable func _route_listPosts(req: Request) async throws -> Response {
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await listPosts(req: req, userID: int0)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                let group = routes.grouped("users", ":int0")
                group.get("posts") { req async throws -> Response in
                    try await self._route_listPosts(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test Controller with dynamic prefix and dynamic route param")
    func testControllerWithDynamicPrefixAndRouteParam() async throws {
        assertMacroExpansion(
            """
            @Controller("users", Int.self)
            struct UserController {
                @GET("posts", String.self)
                func getPost(req: Request, userID: Int, slug: String) async throws -> String {
                    return "post \\(slug) for user \\(userID)"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func getPost(req: Request, userID: Int, slug: String) async throws -> String {
                    return "post \\(slug) for user \\(userID)"
                }

                @Sendable func _route_getPost(req: Request) async throws -> Response {
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let string1 = try req.parameters.require("string1", as: String.self)
                    let result: some ResponseEncodable = try await getPost(req: req, userID: int0, slug: string1)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                let group = routes.grouped("users", ":int0")
                group.get("posts", ":string1") { req async throws -> Response in
                    try await self._route_getPost(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test Controller with empty path prefix is a no-op")
    func testControllerEmptyPathPrefix() async throws {
        assertMacroExpansion(
            """
            @Controller()
            struct UserController {
                @GET("api", "users")
                func list(req: Request) async throws -> String {
                    return "Users"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func list(req: Request) async throws -> String {
                    return "Users"
                }

                @Sendable func _route_list(req: Request) async throws -> Response {
                    let result: some ResponseEncodable = try await list(req: req)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                routes.get("api", "users") { req async throws -> Response in
                    try await self._route_list(req: req)
                }

                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: FailureHandler.instance
        )
    }

    @Test("Test Controller path prefix composes with AuthMiddleware")
    func testControllerPathPrefixWithAuthMiddleware() async throws {
        assertMacroExpansion(
            """
            @Controller("api", "users")
            struct UserController {
                @POST("promote", Int.self)
                @AuthMiddleware(User.self, UserAuthMiddleware())
                func promote(req: Request, user: User, id: Int) async throws -> String {
                    return "promoted"
                }
            }
            """,
            expandedSource: """
            struct UserController {
                func promote(req: Request, user: User, id: Int) async throws -> String {
                    return "promoted"
                }

                @Sendable func _route_promote(req: Request) async throws -> Response {
                    let user = try req.auth.require(User.self)
                    let int0 = try req.parameters.require("int0", as: Int.self)
                    let result: some ResponseEncodable = try await promote(req: req, user: user, id: int0)
                    return try await result.encodeResponse(for: req)
                }
            }

            extension UserController: RouteCollection {
                func boot(routes: any RoutesBuilder) throws {
                let group = routes.grouped("api", "users")
                group.grouped(UserAuthMiddleware()).post("promote", ":int0") { req async throws -> Response in
                    try await self._route_promote(req: req)
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
