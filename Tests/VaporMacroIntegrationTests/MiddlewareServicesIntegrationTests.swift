#if MacroRouting
import HTTPTypes
import RoutingKit
import Testing
import Vapor
import VaporMacros
import VaporTesting

@Suite("Middleware service injection")
struct MiddlewareServicesIntegrationTests {
    @Test("Every injection style retains its registered service and preserves middleware order", arguments: InjectionStyle.allCases)
    func compareInjectionStyles(style: InjectionStyle) async throws {
        try await withApp { app in
            let registrations = [("first", ServiceCalls()), ("second", ServiceCalls())]
            for (name, calls) in registrations {
                try await style.register(on: app.grouped(PathComponent(stringLiteral: name)), client: NamedClient(name: name, calls: calls))
            }
            #expect(MiddlewareTaskServices.client == nil)

            // Rebinding during requests must not replace services captured during registration.
            let requestCalls = ServiceCalls()
            try await MiddlewareTaskServices.$client.withValue(NamedClient(name: "request", calls: requestCalls)) {
                try await app.testing { client in
                    for (name, calls) in registrations {
                        for route in ["attached", "group", "optional"] {
                            let response = try await client.get(
                                URI(string: "/\(name)/\(route)"), headers: [.authorization: "Bearer test-token"])
                            #expect(response.status == .ok)
                            try #expect(await response.body.requireString() == name)
                            #expect(response.headers[.server] == (route == "attached" ? nil : name))
                        }
                        #expect(await calls.paths == ["/auth", "/before", "/auth", "/after", "/before", "/auth", "/after"])
                    }
                }
            }
            #expect(await requestCalls.paths.isEmpty)
            #expect(MiddlewareTaskServices.client == nil)
        }
    }

    @Test("Every injection style enforces required auth and supports optional auth", arguments: InjectionStyle.allCases)
    func compareAuthentication(style: InjectionStyle) async throws {
        try await withApp { app in
            let calls = ServiceCalls()
            try await style.register(on: app, client: NamedClient(name: "authenticated", calls: calls))
            try await app.testing { client in
                for headers: HTTPFields in [[:], [.authorization: "Bearer invalid-token"]] {
                    for route in ["attached", "group"] {
                        let response = try await client.get(URI(string: "/\(route)"), headers: headers)
                        #expect(response.status == .unauthorized)
                    }
                    let response = try await client.get("/optional", headers: headers)
                    #expect(response.status == .ok)
                    try #expect(await response.body.requireString() == "anonymous")
                    #expect(response.headers[.server] == "authenticated")
                }
            }
            #expect(await !calls.paths.contains("/auth"))
        }
    }

    @Test("Request-time task-local middleware reads the server scope over HTTP", .timeLimit(.minutes(1)), arguments: [false, true])
    func taskLocalRequestLookup(bindWhileServing: Bool) async throws {
        try await withApp { app in
            try await MiddlewareTaskServices.$client.withValue(NamedClient(name: "registration")) {
                try await app.register(collection: RequestTaskLocalServiceController())
            }
            #expect(MiddlewareTaskServices.client == nil)
            let calls = ServiceCalls()
            let servingClient: (any Client)? = bindWhileServing ? NamedClient(name: "serving", calls: calls) : nil
            try await MiddlewareTaskServices.$client.withValue(servingClient) {
                try await app.testing(.running) { client in
                    // The HTTP caller's binding must not be mistaken for the server's context.
                    try await MiddlewareTaskServices.$client.withValue(NamedClient(name: "caller")) {
                        let response = try await client.get("/services/task-local-request")
                        if bindWhileServing {
                            #expect(response.status == .ok)
                            #expect(response.headers[.server] == "serving")
                            try #expect(await response.body.requireString() == "serving")
                            #expect(await calls.paths == ["/before", "/auth", "/after"])
                        } else {
                            #expect(response.status == .internalServerError)
                            #expect(await calls.paths.isEmpty)
                        }
                    }
                }
            }
            #expect(MiddlewareTaskServices.client == nil)
        }
    }

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
    var requiresToken = false

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if requiresToken, request.headers.bearerAuthorization?.token != "test-token" {
            return try await next.respond(to: request)
        }
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

enum InjectionStyle: CaseIterable, Sendable {
    case keyPath
    case factory
    case taskLocal

    func register(on routes: any RoutesBuilder, client: any Client) async throws {
        switch self {
        case .keyPath:
            try await routes.register(collection: KeyPathComparisonController(client: client))
        case .factory:
            try await routes.register(collection: FactoryComparisonController(client: client))
        case .taskLocal:
            try await MiddlewareTaskServices.$client.withValue(client) {
                try await routes.register(collection: TaskLocalComparisonController())
            }
        }
    }
}

@Controller
private struct KeyPathComparisonController {
    let client: any Client
    var authentication: ServiceAuthenticator { ServiceAuthenticator(client: client, requiresToken: true) }
    var headers: ServiceHeaderMiddleware { ServiceHeaderMiddleware(client: client) }

    @GET("attached")
    @AuthMiddleware(ServiceUser.self, using: \Self.authentication)
    func attached(req: Request, user: ServiceUser) async throws -> String { user.name }

    #Middleware(using: \Self.headers) {
        #AuthMiddleware(ServiceUser.self, using: \Self.authentication) {
            @GET("group")
            func group(req: Request, user: ServiceUser) async throws -> String { user.name }

            @GET("optional")
            func optional(req: Request, user: ServiceUser?) async throws -> String { user?.name ?? "anonymous" }
        }
    }
}

@Controller
private struct FactoryComparisonController {
    let client: any Client

    @GET("attached")
    @AuthMiddleware(ServiceUser.self, using: { (controller: Self) in ServiceAuthenticator(client: controller.client, requiresToken: true) })
    func attached(req: Request, user: ServiceUser) async throws -> String { user.name }

    #Middleware(using: { (controller: Self) in ServiceHeaderMiddleware(client: controller.client) }) {
        #AuthMiddleware(
            ServiceUser.self, using: { (controller: Self) in ServiceAuthenticator(client: controller.client, requiresToken: true) }
        ) {
            @GET("group")
            func group(req: Request, user: ServiceUser) async throws -> String { user.name }

            @GET("optional")
            func optional(req: Request, user: ServiceUser?) async throws -> String { user?.name ?? "anonymous" }
        }
    }
}

@Controller
private struct TaskLocalComparisonController {
    @GET("attached")
    @AuthMiddleware(ServiceUser.self, ServiceAuthenticator(client: MiddlewareTaskServices.client!, requiresToken: true))
    func attached(req: Request, user: ServiceUser) async throws -> String { user.name }

    #Middleware(ServiceHeaderMiddleware(client: MiddlewareTaskServices.client!)) {
        #AuthMiddleware(ServiceUser.self, ServiceAuthenticator(client: MiddlewareTaskServices.client!, requiresToken: true)) {
            @GET("group")
            func group(req: Request, user: ServiceUser) async throws -> String { user.name }

            @GET("optional")
            func optional(req: Request, user: ServiceUser?) async throws -> String { user?.name ?? "anonymous" }
        }
    }
}

private struct RequestTaskLocalAuthenticator: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        guard let client = MiddlewareTaskServices.client else {
            throw Abort(.internalServerError, reason: "No client bound while serving requests")
        }
        return try await ServiceAuthenticator(client: client).respond(to: request, chainingTo: next)
    }
}

private struct RequestTaskLocalHeaders: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        guard let client = MiddlewareTaskServices.client else {
            throw Abort(.internalServerError, reason: "No client bound while serving requests")
        }
        return try await ServiceHeaderMiddleware(client: client).respond(to: request, chainingTo: next)
    }
}

@Controller
private struct RequestTaskLocalServiceController {
    #Middleware(RequestTaskLocalHeaders()) {
        #AuthMiddleware(ServiceUser.self, RequestTaskLocalAuthenticator()) {
            @GET("services", "task-local-request")
            func index(req: Request, user: ServiceUser) async throws -> String { user.name }
        }
    }
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
