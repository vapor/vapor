#if MacroRouting
import Testing
import Vapor
import VaporTesting
import VaporMacros
import HTTPTypes
import RoutingKit

@Suite("Controller Macro Integration Tests")
struct ControllerMacroIntegrationTests {

    @Test("GET route returns correct response")
    func controllerGetRoute() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.get("/api/test/users")
                #expect(res.status == .ok)
                try #expect(await res.body.string() == "users")
            }
        }
    }

    @Test("GET route with path parameter")
    func controllerGetRouteWithPathParameter() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.get("/api/test/users/42")
                #expect(res.status == .ok)
                try #expect(await res.body.string() == "user with id: 42")
            }
        }
    }

    @Test("POST route")
    func controllerPostRoute() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.post("/api/test/sync")
                #expect(res.status == .ok)
                try #expect(await res.body.string() == "Sync")
            }
        }
    }

    @Test("POST route decodes content and keeps subsequent path parameters")
    func controllerPostRouteWithBody() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.post("/api/test/users/42", content: CreateUserBody(name: "Vapor"))
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor 42")

                let missingBody = try await client.post("/api/test/users/42")
                #expect(missingBody.status == .unsupportedMediaType)
            }
        }
    }

    @Test("POST body handler can explicitly return no content")
    func controllerPostRouteWithExplicitNoContent() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.post("/api/test/users", content: CreateUserBody(name: "Vapor"))
                #expect(res.status == .noContent)
            }
        }
    }

    @Test("Custom HTTP method route")
    func controllerCustomHTTPMethod() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.patch("/api/test/users/custom")
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "custom HTTP method")
            }
        }
    }

    @Test("Custom HTTP method route with path parameter")
    func controllerCustomHTTPMethodWithPathParameter() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.patch("/api/test/users/custom/7")
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "custom HTTP method with id: 7")
            }
        }
    }

    @Test("Returns 404 for unregistered path")
    func controllerRouteNotFound() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.get("/api/test/nonexistent")
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("GET route returns a ContentEncodable value", .bug("https://github.com/vapor/vapor/issues/3342"))
    func controllerGetRouteReturnsContentEncodable() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.get("/api/test/greeting")
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == #"{"message":"HELLO"}"#)
            }
        }
    }

    @Test("POST route decodes a ContentDecodable body", .bug("https://github.com/vapor/vapor/issues/3342"))
    func controllerPostRouteDecodesContentDecodable() async throws {
        try await withApp { app in
            try await app.register(collection: TestUserController())

            try await app.testing { client in
                let res = try await client.post("/api/test/greetings", content: ["name": "Vapor"])
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == #"{"message":"HELLO, VAPOR"}"#)
            }
        }
    }
}

// MARK: - Test fixtures

struct EncodeOnlyGreeting: ContentEncodable {
    var message: String

    mutating func beforeEncode() throws {
        message = message.uppercased()
    }
}

struct DecodeOnlyGreetingBody: ContentDecodable {
    let name: String
}

// MARK: - Test Controller

struct CreateUserBody: Content {
    let name: String
}

@Controller
struct TestUserController {
    @GET("api", "test", "users")
    func getUsers(req: Request) async throws -> String {
        return "users"
    }

    @GET("api", "test", "greeting")
    func greeting(req: Request) async throws -> EncodeOnlyGreeting {
        EncodeOnlyGreeting(message: "hello")
    }

    @POST(content: DecodeOnlyGreetingBody.self, "api", "test", "greetings")
    func createGreeting(req: Request, body: DecodeOnlyGreetingBody) async throws -> EncodeOnlyGreeting {
        EncodeOnlyGreeting(message: "hello, \(body.name)")
    }

    @GET("api", "test", "users", Int.self)
    func getUser(req: Request, id: Int) async throws -> String {
        return "user with id: \(id)"
    }

    @POST("api", "test", "sync")
    func syncRoute(req: Request) throws -> String {
        "Sync"
    }

    @POST(content: CreateUserBody.self, "api", "test", "users", Int.self)
    func createUser(req: Request, user: CreateUserBody, id: Int) async throws -> String {
        "\(user.name) \(id)"
    }

    @POST(content: CreateUserBody.self, "api", "test", "users")
    func createUserWithExplicitNoContent(req: Request, user: CreateUserBody) async throws -> HTTPResponse.Status {
        _ = user.name
        return .noContent
    }

    @HTTP(.patch, "api", "test", "users", "custom")
    func customHTTPMethod(req: Request) async throws -> String {
        return "custom HTTP method"
    }

    @HTTP(.patch, "api", "test", "users", "custom", Int.self)
    func customHTTPMethodWithPathParameter(req: Request, id: Int) async throws -> String {
        return "custom HTTP method with id: \(id)"
    }
}
#endif
