import Benchmark
import HTTPTypes
import NIOCore
import Vapor

// MARK: Shared application

nonisolated(unsafe) var app: Application!

nonisolated(unsafe) var responder: (any Responder)!

func setUpApplication(_ configure: @Sendable (Application) async throws -> Void) async throws {
    let application = try await Application(.testing)
    try await configure(application)
    app = application
    responder = application.makeResponder()
}

func tearDownApplication() async throws {
    responder = nil
    try await app.shutdown()
    app = nil
}

/// Separate type to avoid the construction of this affecting the benchmark
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

/// A no-op middleware, for measuring the per-layer cost of the chain itself
struct PassthroughMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        try await next.respond(to: request)
    }
}

/// The cheapest possible leaf, so a chain benchmark measures the chain and nothing else
struct EchoResponder: Responder {
    private let response = Response(status: .ok)

    func respond(to request: Request) async throws -> Response {
        self.response
    }
}
