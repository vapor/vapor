import XCTVapor

final class AuthenticationTests: XCTestCase {
    func testBearerAuthenticator() throws {
        struct Test: Authenticatable {
            static func authenticator() -> Authenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: BearerAuthenticator {
            func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
                if bearer.token == "test" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
                return request.eventLoop.makeSucceededFuture(())
            }
        }
        
        let app = Application(.detect(default: .testing))
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
            static func authenticator() -> Authenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: BasicAuthenticator {
            typealias User = Test

            func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void> {
                if basic.username == "test" && basic.password == "secret" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
                return request.eventLoop.makeSucceededFuture(())
            }
        }
        
        let app = Application(.detect(default: .testing))
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
    
    func testBasicAuthenticatorWithRedirect() throws {
        struct Test: Authenticatable {
            static func authenticator() -> Authenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: BasicAuthenticator {
            typealias User = Test

            func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void> {
                if basic.username == "test" && basic.password == "secret" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
                return request.eventLoop.makeSucceededFuture(())
            }
        }
        
        let app = Application(.detect(default: .testing))
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
            static func bearerAuthenticator() -> Authenticator {
                TestBearerAuthenticator()
            }

            static func sessionAuthenticator() -> Authenticator {
                TestSessionAuthenticator()
            }

            var sessionID: String {
                self.name
            }
            var name: String
        }

        struct TestBearerAuthenticator: BearerAuthenticator {
            func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
                if bearer.token == "test" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
                return request.eventLoop.makeSucceededFuture(())
            }
        }

        struct TestSessionAuthenticator: SessionAuthenticator {
            typealias User = Test

            func authenticate(sessionID: String, for request: Request) -> EventLoopFuture<Void> {
                let test = Test(name: sessionID)
                request.auth.login(test)
                return request.eventLoop.makeSucceededFuture(())
            }
        }
        
        let app = Application(.detect(default: .testing))
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
            static func authenticator() -> Authenticator {
                TestAuthenticator()
            }
            var name: String
        }

        struct TestAuthenticator: BearerAuthenticator {
            typealias User = Test

            func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
                request.eventLoop.makeSucceededFuture(())
            }
        }

        var config = Middlewares()
        config.use(Test.authenticator())
    }

    func testAsyncAuthenticator() throws {
        struct Test: Authenticatable {
            static func authenticator(threadPool: NIOThreadPool) -> Authenticator {
                TestAuthenticator(threadPool: threadPool)
            }
            var name: String
        }

        struct TestAuthenticator: BasicAuthenticator {
            typealias User = Test
            let threadPool: NIOThreadPool

            func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void> {
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
                return promise.futureResult
            }
        }

        let app = Application(.detect(default: .testing))
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
