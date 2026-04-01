#if MacroRouting
import Testing
import Vapor
import VaporTesting
import VaporMacros
import HTTPTypes
import RoutingKit

@Suite("Standalone Macro Routing Integration Tests", .disabled(reason: "Looks like the language can't support this at the moment"))
struct StandaloneMacroIntegrationTests {

    @Test("GET macro route returns correct response")
    func standaloneGetRoute() async throws {
        try await withApp { app in
            registerStandaloneRoutes(app)

            try await app.testing().test(.get, "/standalone/hello") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "hello from standalone")
            }
        }
    }

    @Test("GET macro route with path parameter")
    func standaloneGetRouteWithPathParameter() async throws {
        try await withApp { app in
            registerStandaloneRoutes(app)

            try await app.testing().test(.get, "/standalone/users/99") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "standalone user with id: 99")
            }
        }
    }

    @Test("POST macro route")
    func standalonePostRoute() async throws {
        try await withApp { app in
            registerStandaloneRoutes(app)

            try await app.testing().test(.post, "/standalone/create") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "created")
            }
        }
    }

    @Test("DELETE macro route")
    func standaloneDeleteRoute() async throws {
        try await withApp { app in
            registerStandaloneRoutes(app)

            try await app.testing().test(.delete, "/standalone/remove/5") { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "deleted 5")
            }
        }
    }
}

// MARK: - Standalone Routes

func registerStandaloneRoutes(_ app: Application) {
    @GET(on: app, "standalone", "hello")
    @Sendable
    func hello(req: Request) async throws -> String {
        return "hello from standalone"
    }

    @GET(on: app, "standalone", "users", Int.self)
    @Sendable
    func getUser(req: Request, id: Int) async throws -> String {
        return "standalone user with id: \(id)"
    }

    @POST(on: app, "standalone", "create")
    @Sendable
    func create(req: Request) async throws -> String {
        return "created"
    }

    @DELETE(on: app, "standalone", "remove", Int.self)
    @Sendable
    func remove(req: Request, id: Int) async throws -> String {
        return "deleted \(id)"
    }
}
#endif
