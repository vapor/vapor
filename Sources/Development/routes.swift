import Foundation
import Vapor
import NIOCore
import HTTPTypes
import NIOConcurrencyHelpers
import _NIOFileSystem
import VaporMacros

struct Creds: Content {
    var email: String
    var password: String
}

public func routes(_ app: Application) throws {
    app.on(.get, "ping") { req -> StaticString in
        return "123" as StaticString
    }

    #warning("Fix")
    // ( echo -e 'POST /slow-stream HTTP/1.1\r\nContent-Length: 1000000000\r\n\r\n'; dd if=/dev/zero; ) | nc localhost 8080
//    app.on(.post, "slow-stream", body: .stream) { req -> EventLoopFuture<String> in
//        let done = req.eventLoop.makePromise(of: String.self)
//
//        let totalBox = NIOLoopBoundBox(0, eventLoop: req.eventLoop)
//        req.body.drain { result in
//            let promise = req.eventLoop.makePromise(of: Void.self)
//
//            switch result {
//            case .buffer(let buffer):
//                req.eventLoop.scheduleTask(in: .milliseconds(1000)) {
//                    totalBox.value += buffer.readableBytes
//                    promise.succeed(())
//                }
//            case .error(let error):
//                done.fail(error)
//            case .end:
//                promise.succeed(())
//                done.succeed(totalBox.value.description)
//            }
//
//            // manually return pre-completed future
//            // this should balloon in memory
//            // return req.eventLoop.makeSucceededFuture(())
//            
//            // return real future that indicates bytes were handled
//            // this should use very little memory
//            return promise.futureResult
//        }
//
//        return done.futureResult
//    }

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

    app.get("json") { req -> [String: String] in
        return ["foo": "bar"]
    }.description("returns some test json")

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

    app.get("shutdown") { req -> HTTPStatus in
        guard let running = req.application.running else {
            throw Abort(.internalServerError)
        }
        running.stop()
        return .ok
    }

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
    sessions.get("set", ":value") { req -> HTTPStatus in
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
    
    app.directory.viewsDirectory = "/Users/tanner/Desktop"
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

    app.on(.post, "max-256", body: .collect(maxSize: 256)) { req -> HTTPStatus in
        print("in route")
        return .ok
    }

    app.on(.post, "upload", body: .stream) { req -> HTTPStatus in
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
        static func authenticator() -> any Authenticator {
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

    try app.register(collection: UserController())
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
        request.logger.debug("In async middleware - \(number)")
        let response = try await next.respond(to: request)
        request.logger.debug("In async middleware way out - \(number)")
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

@Controller
struct UserController {
    @GET("api", "macros", "users")
    func getUsers(req: Request) async throws -> String {
        return "users"
    }

//    @HTTP(.patch, "api", "macros", "users", "custom")
//    func getCustomHTTPMethod(req: Request) async throws -> String {
//        return "custom HTTP method"
//    }

    @GET("api", "macros", "users", Int.self)
    func getUser(req: Request, id: Int) async throws -> String {
        return "user with id: \(id)"
    }

//    @HTTP(.patch, "api", "macros", "users", "custom", Int.self)
//    func getCustomHTTPMethodWithPathParameter(req: Request, id: Int) async throws -> String {
//        return "custom HTTP method"
//    }
}
