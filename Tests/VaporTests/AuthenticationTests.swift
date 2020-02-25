import XCTVapor

final class AuthenticationTests: XCTestCase {
    func testBearerAuthenticator() throws {
        struct Test: Authenticatable {
            var name: String
        }

        struct TestAuthenticator: BearerAuthenticator {
            typealias User = Test

            func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Test?> {
                guard bearer.token == "test" else {
                    return request.eventLoop.makeSucceededFuture(nil)
                }
                let test = Test(name: "Vapor")
                return request.eventLoop.makeSucceededFuture(test)
            }
        }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.grouped([
            TestAuthenticator(), Test.guardMiddleware()
        ]).get("test") { req -> String in
            try req.authc.require(Test.self).name
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
            var name: String
        }

        struct TestAuthenticator: BasicAuthenticator {
            typealias User = Test

            func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Test?> {
                guard basic.username == "test" && basic.password == "secret" else {
                    return request.eventLoop.makeSucceededFuture(nil)
                }
                let test = Test(name: "Vapor")
                return request.eventLoop.makeSucceededFuture(test)
            }
        }
        
        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.grouped([
            TestAuthenticator(), Test.guardMiddleware()
        ]).get("test") { req -> String in
            try req.authc.require(Test.self).name
        }
        
        let basic = "test:secret".data(using: .utf8)!.base64EncodedString()
        try app.testable().test(.GET, "/test") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }.test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
        }
    }

    func testSessionAuthentication() throws {
        struct Test: Authenticatable, SessionAuthenticatable {
            var sessionID: String? {
                return self.name
            }
            var name: String
        }

        struct TestBearerAuthenticator: BearerAuthenticator {
            typealias User = Test

            func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Test?> {
                guard bearer.token == "test" else {
                    return request.eventLoop.makeSucceededFuture(nil)
                }
                let test = Test(name: "Vapor")
                return request.eventLoop.makeSucceededFuture(test)
            }
        }

        struct TestSessionAuthenticator: SessionAuthenticator {
            typealias User = Test

            func resolve(sessionID: String, for request: Request) -> EventLoopFuture<Test?> {
                let test = Test(name: sessionID)
                return request.eventLoop.makeSucceededFuture(test)
            }
        }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.grouped([
            SessionsMiddleware(session: app.sessions.driver),
            TestSessionAuthenticator(),
            TestBearerAuthenticator(),
            Test.guardMiddleware(),
        ]).get("test") { req -> String in
            try req.authc.require(Test.self).name
        }

        var sessionCookie: HTTPCookies.Value?
        try app.testable().test(.GET, "/test") { res in
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertNil(res.headers.firstValue(name: .setCookie))
        }.test(.GET, "/test", headers: ["Authorization": "Bearer test"]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
            if
                let cookies = HTTPCookies.parse(setCookieHeaders: res.headers[.setCookie]),
                let cookie = cookies["vapor-session"]
            {
                sessionCookie = cookie
            } else {
                XCTFail("No set cookie header")
            }
        }
        .test(.GET, "/test", headers: ["Cookie": sessionCookie!.serialize(name: "vapor-session")]) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Vapor")
            XCTAssertNotNil(res.headers.firstValue(name: .setCookie))
        }
    }

    func testMiddlewareConfigExistential() {
        struct Test: Authenticatable {
            var name: String
        }

        struct TestAuthenticator: BearerAuthenticator {
            typealias User = Test

            func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Test?> {
                return request.eventLoop.makeSucceededFuture(nil)
            }
        }

        var config = Middlewares()
        config.use(TestAuthenticator())
    }
}
