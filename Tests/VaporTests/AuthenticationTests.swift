import NIOCore
import NIOPosix
import Vapor
import VaporTesting
import Testing
import Foundation

@Suite("Authentication Tests")
struct AuthenticationTests {
    @Test("Test Bearer Authenticator")
    func bearerAuthenticator() async throws {
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

        try await withApp { app in
            app.routes.grouped([
                Test.authenticator(), Test.guardMiddleware()
            ]).get("test") { req -> String in
                return try req.auth.require(Test.self).name
            }

            try await app.testing().test(.GET, "/test") { res async in
                #expect(res.status == .unauthorized)
            }
            .test(.GET, "/test", headers: ["Authorization": "Bearer test"]) { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
            .test(.GET, "/test", headers: ["Authorization": "bearer test"]) { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
        }
    }

    @Test("Test Basic Authenticator")
    func basicAuthenticator() async throws {
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

        try await withApp { app in
            app.routes.grouped([
                Test.authenticator(), Test.guardMiddleware()
            ]).get("test") { req -> String in
                return try req.auth.require(Test.self).name
            }

            let basic = "test:secret".data(using: .utf8)!.base64EncodedString()
            try await app.testing().test(.GET, "/test") { res async in
                #expect(res.status == .unauthorized)
            }.test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }.test(.GET, "/test", headers: ["Authorization": "basic \(basic)"]) { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
        }
    }

    @Test("Test Basic Authenticator with Colon in Password")
    func basicAuthenticatorWithColonInPassword() async throws {
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

        try await withApp { app in
            app.routes.grouped([
                Test.authenticator(), Test.guardMiddleware()
            ]).get("test") { req -> String in
                return try req.auth.require(Test.self).name
            }

            let basic = "test:secret:with:colon".data(using: .utf8)!.base64EncodedString()
            try await app.testing().test(.GET, "/test") { res async in
                #expect(res.status == .unauthorized)
            }.test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
        }
    }

    @Test("Test Basic Authenticator with Empty Password")
    func basicAuthenticatorWithEmptyPassword() async throws {
        struct Test: Authenticatable {
            static func authenticator() -> AsyncAuthenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: BasicAuthenticator {
            typealias User = Test

            func authenticate(basic: BasicAuthorization, for request: Request) async throws {
                if basic.username == "test" && basic.password == "" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
                return
            }
        }

        try await withApp { app in
            app.routes.grouped([
                Test.authenticator(), Test.guardMiddleware()
            ]).get("test") { req -> String in
                return try req.auth.require(Test.self).name
            }

            let basic = Data("test:".utf8).base64EncodedString()
            try await app.testing().test(.GET, "/test") { res in
                #expect(res.status == .unauthorized)
            }.test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
        }
    }

    @Test("Test Basic Authenticator with Redirect")
    func basicAuthenticatorWithRedirect() async throws {
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

        let redirectMiddleware = Test.redirectMiddleware { req -> String in
            return "/redirect?orig=\(req.url.path)"
        }

        try await withApp { app in
            app.routes.grouped([
                Test.authenticator(), redirectMiddleware
            ]).get("test") { req -> String in
                return try req.auth.require(Test.self).name
            }

            let basic = "test:secret".data(using: .utf8)!.base64EncodedString()
            try await app.testing().test(.GET, "/test") { res async in
                #expect(res.status == .seeOther)
                #expect(res.headers["Location"].first == "/redirect?orig=/test")
            }.test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
            }
        }
    }

    @Test("Test Session Authentication")
    func sessionAuthentication() async throws {
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

        try await withApp { app in
            app.routes.grouped([
                app.sessions.middleware,
                Test.sessionAuthenticator(),
                Test.bearerAuthenticator(),
                Test.guardMiddleware(),
            ]).get("test") { req -> String in
                try req.auth.require(Test.self).name
            }

            var sessionCookie: HTTPCookies.Value?
            try await app.testing().test(.GET, "/test") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers.first(name: .setCookie) == nil)
            }.test(.GET, "/test", headers: ["Authorization": "Bearer test"]) { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
                if let cookie = res.headers.setCookie?["vapor-session"] {
                    sessionCookie = cookie
                } else {
                    Issue.record("No set cookie header")
                }
            }
            .test(.GET, "/test", headers: ["Cookie": sessionCookie!.serialize(name: "vapor-session")]) { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Vapor")
                #expect(res.headers.first(name: .setCookie) != nil)
            }
        }
    }

    @Test("Test Middleware Config with Existential")
    func middlewareConfigExistential() async {
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
}
