#if compiler(>=5.5) && canImport(_Concurrency)
import XCTVapor

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
final class AsyncAuthenticationTests: XCTestCase {
    func testBearerAuthenticator() throws {
        struct Test: Authenticatable {
            static func authenticator() -> AsyncAuthenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: AsyncBearerAuthenticator {
            func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
                if bearer.token == "test" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
            }
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.grouped([
            Test.authenticator(), Test.guardMiddleware()
        ]).get("test") { req -> String in
            return try req.auth.require(Test.self).name
        }

        try app.testable().test(.GET, "/test") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
        .test(.GET, "/test", headers: ["Authorization": "Bearer test"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
        }
    }

    func testBasicAuthenticator() throws {
        struct Test: Authenticatable {
            static func authenticator() -> AsyncAuthenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: AsyncBasicAuthenticator {
            typealias User = Test

            func authenticate(basic: BasicAuthorization, for request: Request) async throws {
                if basic.username == "test" && basic.password == "secret" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
            }
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.grouped([
            Test.authenticator(), Test.guardMiddleware()
        ]).get("test") { req -> String in
            return try req.auth.require(Test.self).name
        }

        let basic = "test:secret".data(using: .utf8)!.base64EncodedString()
        try app.testable().test(.GET, "/test") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }.test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
        }
    }

    func testBasicAuthenticatorWithColonInPassword() throws {
        struct Test: Authenticatable {
            static func authenticator() -> AsyncAuthenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: AsyncBasicAuthenticator {
            typealias User = Test

            func authenticate(basic: BasicAuthorization, for request: Request) async throws {
                if basic.username == "test" && basic.password == "secret:with:colon" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
            }
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.grouped([
            Test.authenticator(), Test.guardMiddleware()
        ]).get("test") { req -> String in
            return try req.auth.require(Test.self).name
        }

        let basic = "test:secret:with:colon".data(using: .utf8)!.base64EncodedString()
        try app.testable().test(.GET, "/test") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }.test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
        }
    }

    func testBasicAuthenticatorWithRedirect() throws {
        struct Test: Authenticatable {
            static func authenticator() -> AsyncAuthenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: AsyncBasicAuthenticator {
            typealias User = Test

            func authenticate(basic: BasicAuthorization, for request: Request) async throws {
                if basic.username == "test" && basic.password == "secret" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
            }
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        let redirectMiddleware = Test.redirectMiddleware { req -> String in
            return "/redirect?orig=\(req.url.path)"
        }

        app.routes.grouped([
            Test.authenticator(), redirectMiddleware
        ]).get("test") { req -> String in
            return try req.auth.require(Test.self).name
        }

        let basic = "test:secret".data(using: .utf8)!.base64EncodedString()
        try app.testable().test(.GET, "/test") { res in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers["Location"].first, "/redirect?orig=/test")
        }.test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
        }
    }

    func testSessionAuthentication() throws {
        struct Test: Authenticatable, SessionAuthenticatable {
            static func bearerAuthenticator() -> AsyncAuthenticator {
                TestBearerAuthenticator()
            }

            static func sessionAuthenticator() -> AsyncAuthenticator {
                TestSessionAuthenticator()
            }

            var sessionID: String {
                self.name
            }
            var name: String
        }

        struct TestBearerAuthenticator: AsyncBearerAuthenticator {
            func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
                if bearer.token == "test" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
            }
        }

        struct TestSessionAuthenticator: AsyncSessionAuthenticator {
            typealias User = Test

            func authenticate(sessionID: String, for request: Request) async throws {
                let test = Test(name: sessionID)
                request.auth.login(test)
            }
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.grouped([
            app.sessions.middleware,
            Test.sessionAuthenticator(),
            Test.bearerAuthenticator(),
            Test.guardMiddleware(),
        ]).get("test") { req -> String in
            try req.auth.require(Test.self).name
        }

        var sessionCookie: HTTPCookies.Value?
        try app.testable().test(.GET, "/test") { res in
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertNil(res.headers.first(name: .setCookie))
        }.test(.GET, "/test", headers: ["Authorization": "Bearer test"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
            if let cookie = res.headers.setCookie?["vapor-session"] {
                sessionCookie = cookie
            } else {
                XCTFail("No set cookie header")
            }
        }
        .test(.GET, "/test", headers: ["Cookie": sessionCookie!.serialize(name: "vapor-session")]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
            XCTAssertNotNil(res.headers.first(name: .setCookie))
        }
    }

    func testMiddlewareConfigExistential() {
        struct Test: Authenticatable {
            static func authenticator() -> AsyncAuthenticator {
                TestAuthenticator()
            }
            var name: String
        }

        struct TestAuthenticator: AsyncBearerAuthenticator {
            typealias User = Test

            func authenticate(bearer: BearerAuthorization, for request: Request) async throws {}
        }

        var config = Middlewares()
        config.use(Test.authenticator())
    }

    func testAsyncAuthenticator() throws {
        struct Test: Authenticatable {
            static func authenticator(threadPool: NIOThreadPool) -> AsyncAuthenticator {
                TestAuthenticator(threadPool: threadPool)
            }
            var name: String
        }

        struct TestAuthenticator: AsyncBasicAuthenticator {
            typealias User = Test
            let threadPool: NIOThreadPool

            func authenticate(basic: BasicAuthorization, for request: Request) async throws {
                let promise = request.eventLoop.makePromise(of: Void.self)
                self.threadPool.submit { _ in
                    sleep(1)
                    request.eventLoop.execute {
                        if basic.username == "test" && basic.password == "secret" {
                            let test = Test(name: "Vapor")
                            request.auth.login(test)
                        }
                        promise.succeed(())
                    }
                }
                return try await promise.futureResult.get()
            }
        }

        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.grouped([
            Test.authenticator(threadPool: app.threadPool),
            Test.guardMiddleware()
        ]).get("test") { req -> String in
            return try req.auth.require(Test.self).name
        }

        let basic = "test:secret".data(using: .utf8)!.base64EncodedString()
        try app.testable().test(.GET, "/test") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }.test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
        }
    }
}

#endif