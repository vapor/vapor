import XCTVapor

final class AuthenticationTests: XCTestCase {
    func testBearerAuthenticator() throws {
        struct Test: Authenticatable {
            var name: String
        }

        struct TestAuthenticator: BearerAuthenticator {
            typealias User = Test

            let eventLoopGroup: EventLoopGroup

            init(on eventLoopGroup: EventLoopGroup) {
                self.eventLoopGroup = eventLoopGroup
            }

            func authenticate(bearer: BearerAuthorization) -> EventLoopFuture<Test?> {
                guard bearer.token == "test" else {
                    return self.eventLoopGroup.next().makeSucceededFuture(nil)
                }
                let test = Test(name: "Vapor")
                return self.eventLoopGroup.next().makeSucceededFuture(test)
            }
        }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.grouped([
            TestAuthenticator(on: app.eventLoopGroup).middleware(), Test.guardMiddleware()
        ]).get("test") { req -> String in
            return try req.requireAuthenticated(Test.self).name
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

            let eventLoopGroup: EventLoopGroup

            init(on eventLoopGroup: EventLoopGroup) {
                self.eventLoopGroup = eventLoopGroup
            }

            func authenticate(basic: BasicAuthorization) -> EventLoopFuture<Test?> {
                guard basic.username == "test" && basic.password == "secret" else {
                    return self.eventLoopGroup.next().makeSucceededFuture(nil)
                }
                let test = Test(name: "Vapor")
                return self.eventLoopGroup.next().makeSucceededFuture(test)
            }
        }
        
        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.grouped([
            TestAuthenticator(on: app.eventLoopGroup).middleware(), Test.guardMiddleware()
        ]).get("test") { req -> String in
            return try req.requireAuthenticated(Test.self).name
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

            let eventLoopGroup: EventLoopGroup
            init(on eventLoopGroup: EventLoopGroup) {
                self.eventLoopGroup = eventLoopGroup
            }

            func authenticate(bearer: BearerAuthorization) -> EventLoopFuture<Test?> {
                guard bearer.token == "test" else {
                    return self.eventLoopGroup.next().makeSucceededFuture(nil)
                }
                let test = Test(name: "Vapor")
                return self.eventLoopGroup.next().makeSucceededFuture(test)
            }
        }

        struct TestSessionAuthenticator: SessionAuthenticator {
            typealias User = Test

            let eventLoopGroup: EventLoopGroup
            init(on eventLoopGroup: EventLoopGroup) {
                self.eventLoopGroup = eventLoopGroup
            }

            func resolve(sessionID: String) -> EventLoopFuture<Test?> {
                let test = Test(name: sessionID)
                return self.eventLoopGroup.next().makeSucceededFuture(test)
            }
        }
        
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.routes.grouped([
            SessionsMiddleware(sessions: app.sessions),
            TestSessionAuthenticator(on: app.eventLoopGroup).middleware(),
            TestBearerAuthenticator(on: app.eventLoopGroup).middleware(),
            Test.guardMiddleware(),
        ]).get("test") { req -> String in
            return try req.requireAuthenticated(Test.self).name
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

            func authenticate(bearer: BearerAuthorization) -> EventLoopFuture<Test?> {
                return EmbeddedEventLoop().makeSucceededFuture(nil)
            }
        }

        var config = Middlewares()
        config.use(TestAuthenticator().middleware())
    }
}
