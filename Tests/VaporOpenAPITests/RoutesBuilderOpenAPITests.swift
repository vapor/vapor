#if OpenAPI
import HTTPTypes
import OpenAPIKit
import RoutingKit
import Testing
import Vapor
@testable import VaporOpenAPI

/// Keeps the routes registered through it, in order.
private final class Collector: RoutesBuilder {
    var routes: [Route] = []
    func add(_ route: Route) { routes.append(route) }
}

private struct Filter: Codable { var page: Int }
private struct Sort: Codable { var by: String }
private struct User: Codable { var id: Int }

/// The names of `parameters`' properties, which become the parameters.
private func names(_ parameters: OpenAPIParameters?) throws -> [String] {
    var components = SchemaComponents()
    return try parameters?.value.parameters(in: .query, into: &components).map(\.name) ?? []
}

@Suite("RoutesBuilder OpenAPI")
struct RoutesBuilderOpenAPITests {
    @Test("A route registered through openAPI carries its details")
    func route() throws {
        let root = Collector()
        root.openAPI(summary: "Get a user", operationID: "getUser", statusCode: .created, deprecated: true)
            .get("users", ":id") { _ in "user" }
        let details = try #require(root.routes.first).openAPIRoute
        #expect(details.summary == "Get a user")
        #expect(details.operationID == "getUser")
        #expect(details.statusCode == .created)
        #expect(details.deprecated == true)
        #expect(!details.isHidden)
    }

    @Test("A route registered without openAPI has no details")
    func plainRoute() throws {
        let root = Collector()
        root.get("plain") { _ in "plain" }
        let route = try #require(root.routes.first)
        #expect(route.openAPI == nil)
        #expect(route.openAPIRoute.summary == nil)
        #expect(route.openAPIRoute.tags.isEmpty)
    }

    @Test("A group's details reach every route in it")
    func group() throws {
        let root = Collector()
        let users = root.openAPI(tags: ["Users"], auth: [.bearer()])
        users.get("a") { _ in "a" }
        users.post("b") { _ in "b" }
        #expect(root.routes.map(\.openAPIRoute.tags) == [["Users"], ["Users"]])
        #expect(root.routes.map { $0.openAPIRoute.auth.map(\.id) } == [["http_bearer"], ["http_bearer"]])
    }

    @Test("A route keeps its own single values over its group's")
    func routeWins() throws {
        let root = Collector()
        root.openAPI(summary: "Users", response: .type(Filter.self), statusCode: .ok)
            .openAPI(summary: "Get a user", response: .type(User.self))
            .get(":id") { _ in "user" }
        let details = try #require(root.routes.first).openAPIRoute
        #expect(details.summary == "Get a user")
        guard case .type(let type) = details.response?.value else {
            Issue.record("The response isn't a type")
            return
        }
        #expect(ObjectIdentifier(type) == ObjectIdentifier(User.self))
        // Unset on the route, so the group's applies.
        #expect(details.statusCode == .ok)
    }

    @Test("Lists add up, the group's first, without duplicates")
    func listsAddUp() throws {
        let root = Collector()
        root.openAPI(tags: ["Users", "Shared"], contentTypes: [.json], auth: [.bearer()])
            .openAPI(tags: ["Admin", "Shared"], contentTypes: [.json, .formData], auth: [.bearer(), .basic()])
            .get("x") { _ in "x" }
        let details = try #require(root.routes.first).openAPIRoute
        #expect(details.tags == ["Users", "Shared", "Admin"])
        #expect(details.contentTypes == [.json, .formData])
        #expect(details.auth.map(\.id) == ["http_bearer", "http_basic"])
    }

    @Test("Parameters from a group and a route are combined, the group's first")
    func parametersCombine() throws {
        let root = Collector()
        root.openAPI(query: .type(Filter.self))
            .openAPI(query: .type(Sort.self))
            .get("x") { _ in "x" }
        #expect(try names(root.routes.first?.openAPIRoute.query) == ["page", "by"])
    }

    @Test("Parameters set on only one side are kept as they are")
    func parametersOneSide() throws {
        let root = Collector()
        root.openAPI(query: .type(Filter.self)).openAPI(summary: "x").get("x") { _ in "x" }
        root.openAPI(summary: "y").openAPI(headers: .type(Sort.self)).get("y") { _ in "y" }
        #expect(try names(root.routes[0].openAPIRoute.query) == ["page"])
        #expect(try names(root.routes[1].openAPIRoute.headers) == ["by"])
        #expect(root.routes[1].openAPIRoute.query == nil)
    }

    @Test("Flags are set if either side sets them")
    func flags() throws {
        let root = Collector()
        root.openAPI(deprecated: true).openAPI(summary: "x").get("x") { _ in "x" }
        #expect(root.routes.first?.openAPIRoute.deprecated == true)
    }

    @Test("A route can undo its group's deprecation")
    func undeprecated() throws {
        let root = Collector()
        root.openAPI(deprecated: true).openAPI(deprecated: false).get("x") { _ in "x" }
        #expect(root.routes.first?.openAPIRoute.deprecated == false)
    }

    @Test("A route's scopes for a scheme replace its group's")
    func authScopes() throws {
        let root = Collector()
        root.openAPI(auth: [.bearer().scopes("read"), .basic()])
            .openAPI(auth: [.bearer().scopes("admin")])
            .get("x") { _ in "x" }
        let auth = try #require(root.routes.first).openAPIRoute.auth
        #expect(auth.map(\.id) == ["http_basic", "http_bearer"])
        #expect(auth.last?.scopes == ["admin"])
    }

    @Test("A route's parameter replaces its group's of the same name")
    func parameterReplaced() throws {
        struct Paging: Codable {
            var limit: Int
            var page: Int
        }
        struct Search: Codable {
            var limit: String
            var q: String
        }
        let root = Collector()
        root.openAPI(query: .type(Paging.self)).openAPI(query: .type(Search.self)).get("x") { _ in "x" }
        var components = SchemaComponents()
        let parameters = try #require(root.routes.first?.openAPIRoute.query).value.parameters(in: .query, into: &components)
        #expect(parameters.map(\.name) == ["page", "limit", "q"])
        // The route's `limit`, a string, not the group's integer.
        #expect(parameters[1].schemaOrContent.schemaValue?.jsonType == .string)
    }

    @Test("Hidden routes stay hidden however they're nested")
    func hidden() throws {
        let root = Collector()
        root.hiddenFromOpenAPI().get("health") { _ in "ok" }
        root.hiddenFromOpenAPI().openAPI(summary: "inner").get("a") { _ in "a" }
        root.openAPI(summary: "outer").hiddenFromOpenAPI().get("b") { _ in "b" }
        #expect(root.routes.map(\.openAPIRoute.isHidden) == [true, true, true])
        #expect(root.routes[1].openAPIRoute.summary == "inner")
    }

    @Test("Details survive Vapor's path and middleware groups around them")
    func vaporGroups() throws {
        let root = Collector()
        root.grouped("api").openAPI(tags: ["API"]).grouped("v1").openAPI(summary: "List").get("users") { _ in "users" }
        let route = try #require(root.routes.first)
        #expect(route.description == "GET /api/v1/users")
        #expect(route.openAPIRoute.tags == ["API"])
        #expect(route.openAPIRoute.summary == "List")
    }
}
#endif
