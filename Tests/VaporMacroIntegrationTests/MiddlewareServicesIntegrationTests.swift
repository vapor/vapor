#if MacroRouting
import HTTPTypes
import RoutingKit
import Testing
import Vapor
import VaporMacros
import VaporTesting

@Suite("Middleware service injection")
struct MiddlewareServicesIntegrationTests {
    @Test("Attached auth middleware resolves the current controller's client", arguments: ["first", "second"])
    func attachedKeyPath(name: String) async throws {
        try await withApp { app in
            try await app.register(collection: ServiceAttributeController(client: NamedClient(name: name)))
            try await app.testing { client in
                for path in ["/services/attribute", "/services/attribute-factory"] {
                    let response = try await client.get(URI(string: path))
                    #expect(response.status == .ok)
                    try #expect(await response.body.requireString() == name)
                }
            }
        }
    }

    @Test("Key-path groups compose with auth factories and preserve middleware order")
    func nestedGroups() async throws {
        try await withApp { app in
            let calls = ServiceCalls()
            try await app.register(collection: ServiceGroupController(client: NamedClient(name: "group", calls: calls)))
            try await app.testing { client in
                let response = try await client.get("/services/group/42")
                #expect(response.status == .ok)
                #expect(response.headers[.server] == "group")
                try #expect(await response.body.requireString() == "group:42")
                #expect(await calls.paths == ["/before", "/auth", "/after"])
                let plain = try await client.get("/services/plain")
                #expect(plain.status == .ok)
                #expect(plain.headers[.server] == nil)
                #expect(await calls.paths == ["/before", "/auth", "/after"])
            }
        }
    }

    @Test("An auth key-path group can wrap a factory middleware group")
    func reverseNesting() async throws {
        try await withApp { app in
            let calls = ServiceCalls()
            try await app.register(collection: ReverseServiceGroupController(client: NamedClient(name: "reverse", calls: calls)))
            try await app.testing { client in
                let response = try await client.get("/services/reverse")
                #expect(response.status == .ok)
                try #expect(await response.body.requireString() == "reverse")
                #expect(await calls.paths == ["/auth", "/before", "/after"])
            }
        }
    }

    @Test("Explicit body arguments and stored middleware properties compile")
    func explicitBody() async throws {
        try await withApp { app in
            try await app.register(
                collection: StoredServiceController(authentication: ServiceAuthenticator(client: NamedClient(name: "stored"))))
            try await app.testing { client in
                let response = try await client.get("/services/stored")
                #expect(response.status == .ok)
                try #expect(await response.body.requireString() == "stored")
            }
        }
    }

    @Test("Task-local injection captures the client at registration and survives leaving the scope")
    func taskLocalCapture() async throws {
        try await withApp { app in
            #expect(MiddlewareTaskServices.client == nil)
            try await MiddlewareTaskServices.$client.withValue(NamedClient(name: "task-local")) {
                try await app.register(collection: TaskLocalServiceController())
                let detachedHasClient = await Task.detached { MiddlewareTaskServices.client != nil }.value
                #expect(!detachedHasClient)
            }
            #expect(MiddlewareTaskServices.client == nil)
            try await app.testing { client in
                let response = try await client.get("/services/task-local")
                #expect(response.status == .ok)
                try #expect(await response.body.requireString() == "task-local")
            }
        }
    }
}

private actor ServiceCalls {
    var paths: [String] = []
    func record(_ path: String) { paths.append(path) }
}

private struct NamedClient: Client {
    let name: String
    var calls: ServiceCalls? = nil
    let contentConfiguration = ContentConfiguration.default()

    func send(_ request: ClientRequest) async throws -> ClientResponse {
        await calls?.record(request.url.path)
        return ClientResponse(body: .init(string: name))
    }
}

private struct ServiceUser: Authenticatable {
    let name: String
}

private struct ServiceAuthenticator: Middleware {
    let client: any Client

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        let response = try await client.get("https://service.invalid/auth")
        request.auth.login(ServiceUser(name: response.body.string ?? ""))
        return try await next.respond(to: request)
    }
}

private struct ServiceHeaderMiddleware: Middleware {
    let client: any Client

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        let serviceResponse = try await client.get("https://service.invalid/before")
        var response = try await next.respond(to: request)
        _ = try await client.get("https://service.invalid/after")
        response.headers[.server] = serviceResponse.body.string
        return response
    }
}

@Controller
private struct ServiceAttributeController {
    let client: any Client
    var authentication: ServiceAuthenticator { ServiceAuthenticator(client: client) }

    @GET("services", "attribute")
    @AuthMiddleware(ServiceUser.self, using: \Self.authentication)
    func index(req: Request, user: ServiceUser) async throws -> String { user.name }

    @GET("services", "attribute-factory")
    @AuthMiddleware(ServiceUser.self, using: { (controller: Self) in ServiceAuthenticator(client: controller.client) })
    func factory(req: Request, user: ServiceUser) async throws -> String { user.name }
}

@Controller
private struct ServiceGroupController {
    let client: any Client
    var headers: ServiceHeaderMiddleware { ServiceHeaderMiddleware(client: client) }

    #Middleware(using: \Self.headers) {
        #AuthMiddleware(ServiceUser.self, using: { (controller: Self) in ServiceAuthenticator(client: controller.client) }) {
            @GET("services", "group", Int.self)
            func index(req: Request, user: ServiceUser, id: Int) async throws -> String { "\(user.name):\(id)" }
        }
    }

    @GET("services", "plain")
    func plain(req: Request) async throws -> String { "plain" }
}

@Controller
private struct ReverseServiceGroupController {
    let client: any Client
    var authentication: ServiceAuthenticator { ServiceAuthenticator(client: client) }

    #AuthMiddleware(ServiceUser.self, using: \Self.authentication) {
        #Middleware(using: { (controller: Self) in ServiceHeaderMiddleware(client: controller.client) }) {
            @GET("services", "reverse")
            func index(req: Request, user: ServiceUser) async throws -> String { user.name }
        }
    }
}

@Controller
private struct StoredServiceController {
    let authentication: ServiceAuthenticator

    #AuthMiddleware(
        ServiceUser.self, using: \Self.authentication,
        body: {
            @GET("services", "stored")
            func index(req: Request, user: ServiceUser) async throws -> String { user.name }
        })
}

private enum MiddlewareTaskServices {
    @TaskLocal static var client: (any Client)?
}

@Controller
private struct TaskLocalServiceController {
    // This lookup happens while registering routes. The middleware retains the client.
    #AuthMiddleware(ServiceUser.self, ServiceAuthenticator(client: MiddlewareTaskServices.client!)) {
        @GET("services", "task-local")
        func index(req: Request, user: ServiceUser) async throws -> String { user.name }
    }
}
#endif
