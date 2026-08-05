import Benchmark
import HTTPTypes
import NIOCore
import RoutingKit
import Vapor

// MARK: Shared application

/// The application under benchmark.
///
/// `Benchmark.setup` and `Benchmark.teardown` run around every individual benchmark, so this is
/// built and shut down cleanly for each one and never measured.
nonisolated(unsafe) var app: Application!

/// The assembled responder chain — trie routing, the middleware stack, handler dispatch and
/// response encoding.
nonisolated(unsafe) var responder: (any Responder)!

func setUpApplication(_ configure: @Sendable (Application) async throws -> Void) async throws {
    let application = try await Application(.testing)
    try await configure(application)
    app = application
    responder = BenchmarkResponder(
        routes: application.routes,
        middleware: application.middleware.resolve()
    )
}

func tearDownApplication() async throws {
    responder = nil
    try await app.shutdown()
    app = nil
}

// MARK: Driving a request

/// A request to issue, built once outside the measured loop so that only the `Request` allocation
/// and the responder chain are timed.
struct RequestCall {
    var method: HTTPRequest.Method
    var path: String
    var headers: HTTPFields
    var body: ByteBuffer?

    init(
        _ method: HTTPRequest.Method = .get,
        _ path: String,
        headers: HTTPFields = [:],
        body: ByteBuffer? = nil
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

/// Builds a fresh `Request` and runs it through the full responder chain.
///
/// A new `Request` per call is deliberate and realistic — a real server allocates one per request,
/// and route parameters are written into it during routing so it cannot be reused. Subtract the
/// `request/create` benchmark to isolate the routing and handler cost.
func run(_ call: RequestCall) async throws -> Response {
    let request = Request(
        application: app,
        method: call.method,
        url: URI(string: call.path),
        headers: call.headers,
        collectedBody: call.body
    )
    return try await responder.respond(to: request)
}

/// A copy of Vapor's `DefaultResponder`, which is `package`-scoped and therefore invisible from
/// this package. Everything it is built from — `Routes.all`, `Route.responder`,
/// `[any Middleware].makeResponder(chainingTo:)`, RoutingKit's trie and `RouteNotFound` — is
/// public, so this exercises exactly the same machinery.
///
/// Keep it in step with `Sources/Vapor/Responder/DefaultResponder.swift`.
struct BenchmarkResponder: Responder {
    private let router: TrieRouter<CachedRoute>
    private let notFoundResponder: any Responder

    private struct CachedRoute {
        let route: Route
        let responder: any Responder
    }

    init(routes: Routes, middleware: [any Middleware] = []) {
        let config = TrieRouter<CachedRoute>.Configuration(isCaseInsensitive: routes.caseInsensitive)
        var routerBuilder = TrieRouterBuilder(CachedRoute.self, config: config)

        for route in routes.all {
            let cached = CachedRoute(
                route: route,
                responder: middleware.makeResponder(chainingTo: route.responder)
            )
            let path = route.path.filter { component in
                switch component {
                case .constant(let string): string != ""
                default: true
                }
            }
            routerBuilder.register(cached, at: [.constant(route.method.rawValue)] + path)
        }

        self.router = routerBuilder.build()
        self.notFoundResponder = middleware.makeResponder(chainingTo: NotFoundResponder())
    }

    func respond(to request: Request) async throws -> Response {
        if let cachedRoute = self.getRoute(for: request) {
            request.route = cachedRoute.route
            return try await cachedRoute.responder.respond(to: request)
        } else {
            return try await self.notFoundResponder.respond(to: request)
        }
    }

    private func getRoute(for request: Request) -> CachedRoute? {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map { String($0).removingPercentEncoding ?? String($0) }

        if request.method == .head, let route = self.router.route(
            path: [HTTPRequest.Method.head.rawValue] + pathComponents,
            parameters: &request.parameters
        ) {
            return route
        }

        let method = (request.method == .head) ? .get : request.method
        return self.router.route(
            path: [method.rawValue] + pathComponents,
            parameters: &request.parameters
        )
    }
}

/// Vapor throws `RouteNotFound` here, whose initialiser is internal. `Abort(.notFound)` is an
/// `AbortError` with the same status, so `ErrorMiddleware` renders it identically.
private struct NotFoundResponder: Responder {
    func respond(to request: Request) async throws -> Response {
        throw Abort(.notFound)
    }
}

// MARK: Fixtures

struct Item: Content, Equatable {
    var id: Int
    var name: String
    var price: Double
    var tags: [String]
}

struct SmallPayload: Content, Equatable {
    var name: String
}

struct Credentials: Content {
    var email: String
    var password: String
}

struct SearchQuery: Content {
    var term: String
    var page: Int
    var perPage: Int
}

func makeItem(_ id: Int = 1) -> Item {
    Item(id: id, name: "Widget \(id)", price: 9.99, tags: ["a", "b", "c"])
}

func makeItems(_ count: Int) -> [Item] {
    (0..<count).map(makeItem)
}

func json(_ string: String) -> ByteBuffer {
    ByteBuffer(string: string)
}

// MARK: Authentication fixtures

struct BenchUser: Authenticatable, Content {
    var id: Int
    var name: String
    var email: String
}

struct BenchToken: Authenticatable {
    var value: String
}

struct BenchBasicAuthenticator: BasicAuthenticator {
    func authenticate(basic: BasicAuthorization, for request: Request) async throws {
        if basic.username == "vapor", basic.password == "secret" {
            request.auth.login(BenchUser(id: 1, name: "Vapor", email: "vapor@vapor.codes"))
        }
    }
}

struct BenchBearerAuthenticator: BearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        if bearer.token == "token" {
            request.auth.login(BenchUser(id: 1, name: "Vapor", email: "vapor@vapor.codes"))
        }
    }
}

/// A no-op middleware, for measuring the per-layer cost of the chain itself.
struct PassthroughMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        try await next.respond(to: request)
    }
}

/// The cheapest possible leaf, so a chain benchmark measures the chain and nothing else.
struct EchoResponder: Responder {
    private let response = Response(status: .ok)

    func respond(to request: Request) async throws -> Response {
        self.response
    }
}
