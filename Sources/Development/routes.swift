import Foundation
import Vapor
import NIOCore
import HTTPTypes
import NIOConcurrencyHelpers
import _NIOFileSystem
import RoutingKit
import Logging
import VaporMacros

struct Creds: Content {
    var email: String
    var password: String
}

func routes(_ app: Application) async throws {
    app.on(.get, "ping") { req -> StaticString in
        return "123" as StaticString
    }

    app.get("hello", "uuid", ":uuid") { req in
        let uuid = try req.parameters.require("uuid", as: UUID.self)
        return uuid.uuidString
    }

    // ( echo -e 'POST /slow-stream HTTP/1.1\r\nContent-Length: 1000000000\r\n\r\n'; dd if=/dev/zero; ) | nc localhost 8080
    app.on(.post, "slow-stream", body: .stream) { req -> String in
        // Consume the streamed body slowly to demonstrate backpressure: sleeping between
        // reads keeps memory flat because the server stops pulling more of the body until
        // this loop asks for the next chunk.
        var total = 0
        for try await buffer in req.body {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            total += buffer.readableBytes
        }
        return total.description
    }

    app.get("test", "head") { req -> String in
        return "OK!"
    }

    app.post("test", "head") { req -> String in
        return "OK!"
    }

    app.post("login") { req -> String in
        let creds = try await req.content.decode(Creds.self)
        return "\(creds)"
    }

    app.on(.post, "large-file", body: .collect(maxSize: 1_000_000_000)) { req -> String in
        return req.body.data?.readableBytes.description  ?? "none"
    }

    app.get("json", routeDescription: "Returns Some Test JSON") { req -> [String: String] in
        return ["foo": "bar"]
    }

    #warning("TODO")
//    app.webSocket("ws") { req, ws in
//        ws.onText { ws, text in
//            ws.send(text.reversed())
//            if text == "close" {
//                ws.close(promise: nil)
//            }
//        }
//
//        let ip = req.remoteAddress?.description ?? "<no ip>"
//        ws.send("Hello 👋 \(ip)")
//    }

    app.on(.post, "file", body: .stream) { req in
        for try await part in req.body {
            debugPrint(part)
        }
        return "Done"
    }

    app.get("stream", "chunks") { _ -> Response in
        Response(body: .init(stream: { writer in
            for i in 1...5 {
                try await writer.write(ByteBuffer(string: "chunk \(i)\n"))
            }
        }))
    }

    app.get("stream", "sequence") { _ -> Response in
        let lines = AsyncStream<ByteBuffer> { continuation in
            for i in 1...10 {
                continuation.yield(ByteBuffer(string: "line \(i)\n"))
            }
            continuation.finish()
        }
        return Response(body: .init(stream: { writer in
            for await chunk in lines {
                try await writer.write(chunk)
            }
        }))
    }

    app.get("stream", "firehose") { _ -> Response in
        Response(body: .init(stream: { writer in
            let chunk = ByteBuffer(repeating: 0x41, count: 16 * 1024)
            for _ in 0..<10_000 {
                try await writer.write(chunk)
            }
        }))
    }

    // Sleeps between chunks: with `curl` you can see each line arrive ~0.5s apart, which shows
    // the write suspends and the response is produced lazily rather than buffered up front.
    app.get("stream", "slow") { _ -> Response in
        Response(body: .init(stream: { writer in
            for i in 1...10 {
                try await writer.write(ByteBuffer(string: "chunk \(i)\n"))
                try await Task.sleep(for: .milliseconds(500))
            }
        }))
    }

    app.get("stream", "file") { _ -> Response in
        let path = #filePath
        let fileSystem = FileSystem.shared
        return Response(body: .init(stream: { writer in
            let handle = try await fileSystem.openFile(forReadingAt: FilePath(path), options: .init())
            defer { try? await handle.close() }
            for try await chunk in handle.readChunks(chunkLength: .bytes(64 * 1024)) {
                try await writer.write(chunk)
            }
        }))
    }

    // TODO: Implement shutdown route using structured concurrency
    // With ServiceGroup, shutdown is triggered via SIGTERM/SIGINT signals

    let cache = MemoryCache()
    app.get("cache", "get", ":key") { req -> String in
        guard let key = req.parameters.get("key") else {
            throw Abort(.internalServerError)
        }
        return "\(key) = \(await cache.get(key) ?? "nil")"
    }
    app.get("cache", "set", ":key", ":value") { req -> String in
        guard let key = req.parameters.get("key") else {
            throw Abort(.internalServerError)
        }
        guard let value = req.parameters.get("value") else {
            throw Abort(.internalServerError)
        }
        await cache.set(key, to: value)
        return "\(key) = \(value)"
    }

    app.get("hello", ":name") { req in
        return req.parameters.get("name") ?? "<nil>"
    }

    app.get("search") { req in
        return req.query["q"] ?? "none"
    }

    let sessions = app.grouped("sessions")
        .grouped(app.sessions.middleware)
    sessions.get("set", ":value") { req -> HTTPResponse.Status in
        req.session.data["name"] = req.parameters.get("value")
        return .ok
    }
    sessions.get("get") { req -> String in
        req.session.data["name"] ?? "n/a"
    }
    sessions.get("del") { req -> String in
        req.session.destroy()
        return "done"
    }

    app.get("client") { req in
        let response = try await req.application.client.get("http://httpbin.org/status/201")
        return response.description
    }

    app.get("client-json") { req in
        struct HTTPBinResponse: Decodable {
            struct Slideshow: Decodable {
                var title: String
            }
            var slideshow: Slideshow
        }
        let response = try await req.application.client.get("http://httpbin.org/json")
        let data = try await response.content.decode(HTTPBinResponse.self)
        return data.slideshow.title
    }

    let users = app.grouped("users")
    users.get { req in
        return "users"
    }
    users.get(":userID") { req in
        return req.parameters.get("userID") ?? "no id"
    }

    app.get("view") { req in
        try await req.view.render("hello.txt", ["name": "world"])
    }

    app.get("error") { req -> String in
        throw TestError()
    }

    app.get("secret") { req in
        guard let secret = try await Environment.secret(path: "PASSWORD_SECRET") else {
            throw Abort(.badRequest)
        }
        return secret
    }

    app.on(.post, "max-256", body: .collect(maxSize: 256)) { req -> HTTPResponse.Status in
        print("in route")
        return .ok
    }

    #if !canImport(FoundationEssentials)
    app.on(.post, "upload", body: .stream) { req -> HTTPResponse.Status in
        return try await FileSystem.shared.withFileHandle(
            forWritingAt: .init(Bundle.module.url(forResource: "Resources/fileio", withExtension: "txt")?.path ?? ""),
            options: .newFile(replaceExisting: true)) { handle in
                var writer = handle.bufferedWriter()
                for try await part in req.body {
                    try await writer.write(contentsOf: part)
                }
                return .ok
            }
    }
    #endif

    let asyncRoutes = app.grouped("async").grouped(TestMiddleware(number: 1))
    asyncRoutes.get("client") { req async throws -> String in
        let response = try await req.application.client.get("https://www.google.com")
        guard let body = response.body else {
            throw Abort(.internalServerError)
        }
        return String(buffer: body)
    }

    asyncRoutes.get("client2") { req -> String in
        let response = try await req.application.client.get("https://www.google.com")
        guard let body = response.body else {
            throw Abort(.internalServerError)
        }
        return String(buffer: body)
    }

    asyncRoutes.get("content") { req in
        Creds(email: "name", password: "password")
    }

    asyncRoutes.get("content2") { req async throws -> Creds in
        return Creds(email: "name", password: "password")
    }

    asyncRoutes.get("contentArray") { req async throws -> [Creds] in
        let cred1 = Creds(email: "name", password: "password")
        return [cred1]
    }

    @Sendable
    func opaqueRouteTester(_ req: Request) async throws -> some ResponseEncodable {
        "Hello World"
    }
    asyncRoutes.get("opaque", use: opaqueRouteTester)

    let basicAuthRoutes = asyncRoutes.grouped(Test.authenticator(), Test.guardMiddleware())
    basicAuthRoutes.get("auth") { req async throws -> String in
        return try req.auth.require(Test.self).name
    }

    struct Test: Authenticatable {
        static func authenticator() -> any RequestAuthenticator {
            TestAuthenticator()
        }

        var name: String
    }

    struct TestAuthenticator: BasicAuthenticator {
        typealias User = Test

        func authenticate(basic: BasicAuthorization, for request: Request) async throws {
            if basic.username == "test" && basic.password == "secret" {
                let test = Test(name: "Vapor")
                request.auth.login(test)
            }
        }
    }

    app.get("matching", "partial", ":{my-file}.json") { req in
        let fileName = try req.parameters.require("my-file")
        return "Hello, \(fileName)"
    }

    #if MacroRouting
    try await app.register(collection: UserController())

    #GET(on: app, "macros", "types", Int.self) { (req: Request, id: Int) async throws -> String in
        return "macro route with id: \(id)"
    }
    #endif
}

struct TestError: AbortError, DebuggableError {
    var status: HTTPResponse.Status {
        .internalServerError
    }

    var reason: String {
        "This is a test."
    }

    var source: ErrorSource?

    init(
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column,
        range: Range<UInt>? = nil
    ) {
        self.source = .init(
            file: file,
            function: function,
            line: line,
            column: column,
            range: range
        )
    }
}

struct TestMiddleware: Middleware {
    let number: Int

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        Logger.current.debug("In async middleware - \(number)")
        let response = try await next.respond(to: request)
        Logger.current.debug("In async middleware way out - \(number)")
        return response
    }
}

struct TestController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("test", use: testRoute)
    }

    func testRoute(_ req: Request) async throws -> String {
        return "OK"
    }
}

#if MacroRouting
@Controller
struct UserController {
    @GET("api", "macros", "users")
    func getUsers(req: Request) async throws -> String {
        return "users"
    }

    @HTTP(.patch, "api", "macros", "users", "custom")
    func getCustomHTTPMethod(req: Request) async throws -> String {
        return "custom HTTP method"
    }

    @GET("api", "macros", "users", Int.self)
    func getUser(req: Request, id: Int) async throws -> String {
        return "user with id: \(id)"
    }

    @HTTP(.patch, "api", "macros", "users", "custom", Int.self)
    func getCustomHTTPMethodWithPathParameter(req: Request, id: Int) async throws -> String {
        return "custom HTTP method"
    }

    @POST("api", "macros", "lots", UUID.self, Int.self, String.self, Int.self)
    func getLotsOfParameters(req: Request, uuid: UUID, number: Int, text: String, anotherNumber: Int) async throws -> String {
        return "uuid: \(uuid), number: \(number), text: \(text), anotherNumber: \(anotherNumber)"
    }

    @POST("api", "macros", "sync")
    func syncRoute(req: Request) throws -> String {
        "Sync"
    }

    @GET("macros", "manual", "int", ":id")
    @Sendable
    func macroDynamicPathParameter(req: Request) async throws -> String {
        let id = try req.parameters.require("id")
        return "macro route with id: \(id)"
    }

    @GET("macros", "manual", "partial", ":{my-file}.json")
    @Sendable
    func macroDynamicPartialPathParameter(req: Request) async throws -> String {
        let file = try req.parameters.require("my-file")
        return "macro route with file: \(file)"
    }

    @POST("api", "macros", "users", Int.self, "promote")
    @AuthMiddleware(User.self, UserAuthMiddleware())
    func promoteUser(req: Request, authenticatedUser: User, id: Int) async throws -> User {
        // Must have: Request, User, then Int (in that order)
        return authenticatedUser
    }

//    These routes are expected not to compile and are here to demonstate/test that
//    @GET("NotResponseCodable")
//    func testNotARoute(req: Request) async throws -> NotContentType {
//        NotContentType(something: "")
//    }

//    @GET("Void")
//    func testVoidRoute(req: Request) throws {
//
//    }
}
#endif

struct NotContentType {
    let something: String
}

struct User: Authenticatable, Content {
    let id: Int
    let name: String
}

struct UserAuthMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        if let authHeader = request.headers[.authorization], authHeader == "Bearer token" {
            request.auth.login(User(id: 1, name: "Vapor"))
        }
        return try await next.respond(to: request)
     }
}
