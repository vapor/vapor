#if MacroRouting
import HTTPTypes
import RoutingKit
import Vapor
import VaporMacros

// Compare the same middleware with three ways of supplying its Client:
//   GET /api/macros/middleware/{key-path,factory,task-local}/me
//   GET /api/macros/middleware/{key-path,factory,task-local}/attached
// Send `Authorization: Bearer demo-token` to receive {"name":"Vapor"}.
// Without a valid token, each route returns 401. The grouped /me routes also
// fetch a service label and include it in the X-Example-Service response header.
func middlewareServiceExamples(_ app: Application) async throws {
    // An in-process Client keeps these examples runnable without an external API.
    // Real applications supply their configured client or database pool here.
    let client = MiddlewareExampleClient()
    let routes = app.grouped("api", "macros", "middleware")
    try await routes.grouped("key-path").register(collection: KeyPathMiddlewareController(client: client))
    try await routes.grouped("factory").register(collection: FactoryMiddlewareController(client: client))

    // The generated boot(routes:) reads the task local when constructing middleware.
    // Each middleware stores the Client, so this binding can end before serving.
    try await MiddlewareExampleServices.$client.withValue(client) {
        try await routes.grouped("task-local").register(collection: TaskLocalMiddlewareController())
    }
}

@Controller
private struct KeyPathMiddlewareController {
    let client: any Client

    var authentication: ExampleAPIAuthenticator { ExampleAPIAuthenticator(client: client) }
    var serviceHeader: ExampleServiceHeaderMiddleware { ExampleServiceHeaderMiddleware(client: client) }

    #Middleware(using: \Self.serviceHeader) {
        #AuthMiddleware(MiddlewareExampleUser.self, using: \Self.authentication) {
            @GET("me")
            func me(req: Request, user: MiddlewareExampleUser) async throws -> MiddlewareExampleUser { user }
        }
    }

    @GET("attached")
    @AuthMiddleware(MiddlewareExampleUser.self, using: \Self.authentication)
    func attached(req: Request, user: MiddlewareExampleUser) async throws -> MiddlewareExampleUser { user }
}

@Controller
private struct FactoryMiddlewareController {
    let client: any Client

    #Middleware(using: { (controller: Self) in ExampleServiceHeaderMiddleware(client: controller.client) }) {
        #AuthMiddleware(MiddlewareExampleUser.self, using: { (controller: Self) in ExampleAPIAuthenticator(client: controller.client) }) {
            @GET("me")
            func me(req: Request, user: MiddlewareExampleUser) async throws -> MiddlewareExampleUser { user }
        }
    }

    @GET("attached")
    @AuthMiddleware(MiddlewareExampleUser.self, using: { (controller: Self) in ExampleAPIAuthenticator(client: controller.client) })
    func attached(req: Request, user: MiddlewareExampleUser) async throws -> MiddlewareExampleUser { user }
}

private enum MiddlewareExampleServices {
    @TaskLocal static var client: (any Client)?
}

@Controller
private struct TaskLocalMiddlewareController {
    // These expressions run inside the withValue scope in middlewareServiceExamples.
    #Middleware(ExampleServiceHeaderMiddleware(client: MiddlewareExampleServices.client!)) {
        #AuthMiddleware(MiddlewareExampleUser.self, ExampleAPIAuthenticator(client: MiddlewareExampleServices.client!)) {
            @GET("me")
            func me(req: Request, user: MiddlewareExampleUser) async throws -> MiddlewareExampleUser { user }
        }
    }

    @GET("attached")
    @AuthMiddleware(MiddlewareExampleUser.self, ExampleAPIAuthenticator(client: MiddlewareExampleServices.client!))
    func attached(req: Request, user: MiddlewareExampleUser) async throws -> MiddlewareExampleUser { user }
}

private struct MiddlewareExampleUser: Authenticatable, Content {
    let name: String
}

private struct ExampleAPIAuthenticator: Middleware {
    let client: any Client

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if let authorization = request.headers[.authorization] {
            let response = try await client.get("https://middleware.example/user", headers: [.authorization: authorization])
            if response.status == .ok {
                let name = try await response.content.decode(String.self)
                request.auth.login(MiddlewareExampleUser(name: name))
            }
        }
        return try await next.respond(to: request)
    }
}

private struct ExampleServiceHeaderMiddleware: Middleware {
    let client: any Client

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        let service = try await client.get("https://middleware.example/status")
        let label = try await service.content.decode(String.self)
        var response = try await next.respond(to: request)
        response.headers[HTTPField.Name("X-Example-Service")!] = label
        return response
    }
}

// A deterministic stand-in for a third-party API. Both middlewares use the
// injected Client protocol, and all three controllers receive the same service.
private struct MiddlewareExampleClient: Client {
    let contentConfiguration = ContentConfiguration.default()

    func send(_ request: ClientRequest) async throws -> ClientResponse {
        let value: String
        switch request.url.path {
        case "/status":
            value = "example-api"
        case "/user":
            guard request.headers.bearerAuthorization?.token == "demo-token" else {
                return ClientResponse(status: .unauthorized)
            }
            value = "Vapor"
        default:
            return ClientResponse(status: .notFound)
        }
        var response = ClientResponse()
        try response.content.encode(value, as: .json)
        return response
    }
}
#endif
