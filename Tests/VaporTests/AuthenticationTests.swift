import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import Vapor
import VaporTesting
import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes
import RoutingKit

@Suite("Authentication Tests")
struct AuthenticationTests {
    @Test("Test Bearer Authenticator")
    func bearerAuthenticator() async throws {
        struct Test: Authenticatable {
            static func authenticator() -> any RequestAuthenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: BearerAuthenticator {
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

            try await app.testing().test(.get, "/test") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Bearer realm="Vapor""#)
            }

            try await app.testing().test(.get, "/test", headers: [.authorization: "Bearer test"]) { res async in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
                #expect(res.headers[.wwwAuthenticate] == nil)
            }

            try await app.testing().test(.get, "/test", headers: [.authorization: "bearer test"]) { res async in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
            }
        }
    }

    @Test("Test Basic Authenticator")
    func basicAuthenticator() async throws {
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

        try await withApp { app in
            app.routes.grouped([
                Test.authenticator(), Test.guardMiddleware()
            ]).get("test") { req -> String in
                return try req.auth.require(Test.self).name
            }

            let basic = "test:secret".data(using: .utf8)!.base64EncodedString()
            try await app.testing().test(.get, "/test") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Basic realm="Vapor", charset="UTF-8""#)
            }

            try await app.testing().test(.get, "/test", headers: [.authorization: "Basic \(basic)"]) { res async in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
                #expect(res.headers[.wwwAuthenticate] == nil)
            }

            try await app.testing().test(.get, "/test", headers: [.authorization: "basic \(basic)"]) { res async in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
            }
        }
    }

    @Test("Test Basic Authenticator WWW Authenticate Header")
    func basicAuthenticatorWWWAuthenticateHeader() async throws {
        struct TestAuthenticator: BasicAuthenticator {
            let realm = #"Private "Area""#

            func authenticate(basic: BasicAuthorization, for request: Request) async throws { }
        }

        try await withApp { app in
            app.routes.grouped(TestAuthenticator()).get("test") { _ in
                Response(status: .unauthorized)
            }
            app.routes.grouped(TestAuthenticator()).get("existing") { _ -> Response in
                var response = Response(status: .unauthorized)
                response.headers[.wwwAuthenticate] = #"Basic realm="Existing""#
                return response
            }

            try await app.testing().test(.get, "/test") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Basic realm="Private \"Area\"", charset="UTF-8""#)
            }

            try await app.testing().test(.get, "/existing") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Basic realm="Existing""#)
            }
        }
    }

    @Test("Test Bearer Authenticator WWW Authenticate Header")
    func bearerAuthenticatorWWWAuthenticateHeader() async throws {
        struct DefaultRealmAuthenticator: BearerAuthenticator {
            func authenticate(bearer: BearerAuthorization, for request: Request) async throws { }
        }

        struct CustomRealmAuthenticator: BearerAuthenticator {
            let realm = #"API "v2""#

            func authenticate(bearer: BearerAuthorization, for request: Request) async throws { }
        }

        try await withApp { app in
            app.routes.grouped(DefaultRealmAuthenticator()).get("default") { _ in
                Response(status: .unauthorized)
            }
            app.routes.grouped(CustomRealmAuthenticator()).get("custom") { _ in
                Response(status: .unauthorized)
            }
            app.routes.grouped(CustomRealmAuthenticator()).get("existing") { _ -> Response in
                var response = Response(status: .unauthorized)
                response.headers[.wwwAuthenticate] = #"Bearer realm="Existing""#
                return response
            }
            app.routes.grouped(CustomRealmAuthenticator()).get("ok") { _ in
                Response(status: .ok)
            }

            try await app.testing().test(.get, "/default") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Bearer realm="Vapor""#)
            }

            try await app.testing().test(.get, "/custom") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Bearer realm="API \"v2\"""#)
            }

            // A challenge the responder chain set itself must not be replaced.
            try await app.testing().test(.get, "/existing") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Bearer realm="Existing""#)
            }

            // Only unauthorized responses get a challenge.
            try await app.testing().test(.get, "/ok") { res async in
                #expect(res.status == .ok)
                #expect(res.headers[.wwwAuthenticate] == nil)
            }
        }
    }

    @Test("Test Throwing Authenticator WWW Authenticate Header")
    func throwingAuthenticatorWWWAuthenticateHeader() async throws {
        struct NotAnAbortError: Error { }

        struct TestAuthenticator: BearerAuthenticator {
            let realm = "API"

            func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
                switch bearer.token {
                case "revoked":
                    throw Abort(.unauthorized, reason: "Token has been revoked.")
                case "expired":
                    var headers = HTTPFields()
                    headers.wwwAuthenticate = #"Bearer realm="API", error="invalid_token""#
                    throw Abort(.unauthorized, headers: headers, reason: "Token has expired.")
                case "forbidden":
                    throw Abort(.forbidden, reason: "Insufficient scope.")
                default:
                    throw NotAnAbortError()
                }
            }
        }

        try await withApp { app in
            app.routes.grouped(TestAuthenticator()).get("test") { _ in
                Response(status: .ok)
            }

            // An unauthorized error picks up the challenge but keeps its own reason.
            try await app.testing().test(.get, "/test", headers: [.authorization: "Bearer revoked"]) { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Bearer realm="API""#)
                try #expect(await res.body.requireString().contains("Token has been revoked."))
            }

            // An error carrying its own challenge keeps it verbatim.
            try await app.testing().test(.get, "/test", headers: [.authorization: "Bearer expired"]) { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Bearer realm="API", error="invalid_token""#)
                try #expect(await res.body.requireString().contains("Token has expired."))
            }

            // Errors with any other status are left alone.
            try await app.testing().test(.get, "/test", headers: [.authorization: "Bearer forbidden"]) { res async in
                #expect(res.status == .forbidden)
                #expect(res.headers[.wwwAuthenticate] == nil)
                try #expect(await res.body.requireString().contains("Insufficient scope."))
            }

            try await app.testing().test(.get, "/test", headers: [.authorization: "Bearer nonsense"]) { res async in
                #expect(res.status == .internalServerError)
                #expect(res.headers[.wwwAuthenticate] == nil)
            }
        }
    }

    @Test("Test Authenticator Preserves Thrown Error Details")
    func authenticatorPreservesThrownErrorDetails() async throws {
        struct TestError: AbortError, DebuggableError {
            var status: HTTPResponse.Status { .unauthorized }
            var reason: String { "The credentials have expired." }
            var identifier: String { "credentialsExpired" }
            var source: ErrorSource?
        }

        struct TestAuthenticator: BasicAuthenticator {
            func authenticate(basic: BasicAuthorization, for request: Request) async throws {
                throw TestError(source: .capture())
            }
        }

        struct CapturedError: Sendable {
            var reason: String?
            var challenge: String?
            var identifier: String?
            var source: ErrorSource?
        }

        struct ErrorCapturingMiddleware: Middleware {
            let captured: NIOLockedValueBox<CapturedError?>

            func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
                do {
                    return try await next.respond(to: request)
                } catch {
                    self.captured.withLockedValue {
                        $0 = CapturedError(
                            reason: (error as? any AbortError)?.reason,
                            challenge: (error as? any AbortError)?.headers[.wwwAuthenticate],
                            identifier: (error as? any DebuggableError)?.identifier,
                            source: (error as? any DebuggableError)?.source
                        )
                    }
                    throw error
                }
            }
        }

        let captured = NIOLockedValueBox<CapturedError?>(nil)

        try await withApp { app in
            app.routes.grouped([
                ErrorCapturingMiddleware(captured: captured), TestAuthenticator()
            ]).get("test") { _ in
                Response(status: .ok)
            }

            let basic = "test:secret".data(using: .utf8)!.base64EncodedString()
            try await app.testing().test(.get, "/test", headers: [.authorization: "Basic \(basic)"]) { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Basic realm="Vapor", charset="UTF-8""#)
                try #expect(await res.body.requireString().contains("The credentials have expired."))
            }

            let error = try #require(captured.withLockedValue { $0 })
            #expect(error.reason == "The credentials have expired.")
            #expect(error.challenge == #"Basic realm="Vapor", charset="UTF-8""#)
            // The details of the error that actually rejected the request survive the challenge being added.
            #expect(error.identifier == "credentialsExpired")
            #expect(error.source?.file == #fileID)
        }
    }

    @Test("Test Chained Authenticators WWW Authenticate Header")
    func chainedAuthenticatorsWWWAuthenticateHeader() async throws {
        struct Test: Authenticatable { }

        struct BasicTestAuthenticator: BasicAuthenticator {
            let realm = "Basic Realm"

            func authenticate(basic: BasicAuthorization, for request: Request) async throws { }
        }

        struct BearerTestAuthenticator: BearerAuthenticator {
            let realm = "Bearer Realm"

            func authenticate(bearer: BearerAuthorization, for request: Request) async throws { }
        }

        try await withApp { app in
            // Middleware is applied outermost first, so the *last* authenticator in a chain is the
            // innermost one and stamps its challenge before any of the others see the error. The
            // rethrown error then carries a challenge, so the outer authenticators leave it alone.
            app.routes.grouped([
                BasicTestAuthenticator(), BearerTestAuthenticator(), Test.guardMiddleware()
            ]).get("bearer-innermost") { _ -> String in "" }

            app.routes.grouped([
                BearerTestAuthenticator(), BasicTestAuthenticator(), Test.guardMiddleware()
            ]).get("basic-innermost") { _ -> String in "" }

            // The same ordering applies to a returned response, not just to a thrown error.
            app.routes.grouped([
                BasicTestAuthenticator(), BearerTestAuthenticator()
            ]).get("returned") { _ in
                Response(status: .unauthorized)
            }

            try await app.testing().test(.get, "/bearer-innermost") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Bearer realm="Bearer Realm""#)
                // Only one scheme is advertised, even though the route accepts both.
                #expect(res.headers[values: .wwwAuthenticate].count == 1)
            }

            try await app.testing().test(.get, "/basic-innermost") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Basic realm="Basic Realm", charset="UTF-8""#)
                #expect(res.headers[values: .wwwAuthenticate].count == 1)
            }

            try await app.testing().test(.get, "/returned") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.wwwAuthenticate] == #"Bearer realm="Bearer Realm""#)
            }
        }
    }

    @Test("Test Basic Authenticator with Colon in Password")
    func basicAuthenticatorWithColonInPassword() async throws {
        struct Test: Authenticatable {
            static func authenticator() -> any RequestAuthenticator {
                TestAuthenticator()
            }

            var name: String
        }

        struct TestAuthenticator: BasicAuthenticator {
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
            try await app.testing().test(.get, "/test") { res async in
                #expect(res.status == .unauthorized)
            }

            try await app.testing().test(.get, "/test", headers: [.authorization: "Basic \(basic)"]) { res async in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
            }
        }
    }

    @Test("Test Basic Authenticator with Empty Password")
    func basicAuthenticatorWithEmptyPassword() async throws {
        struct Test: Authenticatable {
            static func authenticator() -> any RequestAuthenticator {
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
            try await app.testing().test(.get, "/test") { res in
                #expect(res.status == .unauthorized)
            }

            try await app.testing().test(.get, "/test", headers: [.authorization: "Basic \(basic)"]) { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
            }
        }
    }

    @Test("Test Basic Authenticator with Redirect")
    func basicAuthenticatorWithRedirect() async throws {
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
            try await app.testing().test(.get, "/test") { res async in
                #expect(res.status == .seeOther)
                #expect(res.headers[.location] == "/redirect?orig=/test")
            }

            try await app.testing().test(.get, "/test", headers: [.authorization: "Basic \(basic)"]) { res async in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
            }
        }
    }

    @Test("Test Session Authentication")
    func sessionAuthentication() async throws {
        struct Test: Authenticatable, SessionAuthenticatable {
            static func bearerAuthenticator() -> any RequestAuthenticator {
                TestBearerAuthenticator()
            }

            static func sessionAuthenticator() -> any RequestAuthenticator {
                TestSessionAuthenticator()
            }

            var sessionID: String {
                self.name
            }
            var name: String
        }

        struct TestBearerAuthenticator: BearerAuthenticator {
            func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
                if bearer.token == "test" {
                    let test = Test(name: "Vapor")
                    request.auth.login(test)
                }
            }
        }

        struct TestSessionAuthenticator: SessionAuthenticator {
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
            try await app.testing().test(.get, "/test") { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers[.setCookie] == nil)
            }

            try await app.testing().test(.get, "/test", headers: [.authorization: "Bearer test"]) { res async in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
                if let cookie = res.headers.setCookie?["vapor-session"] {
                    sessionCookie = cookie
                } else {
                    Issue.record("No set cookie header")
                }
            }

            try await app.testing().test(.get, "/test", headers: [.cookie: sessionCookie!.serialize(name: "vapor-session")]) { res async in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
                #expect(res.headers[.setCookie] != nil)
            }
        }
    }

    /// A regression test ensuring that if no auth cookie is provided, the `AsyncSessionAuthenticator`
    /// does not end up creating an empty session and sending back `set-cookie`.
    /// This is a valid use case when session-based auth is not required.
    /// In the other test above (testSessionAuthentication), the `set-cookie` header is correctly omitted
    /// because the guard middleware throws an error, which skips the `addCookies` method in
    /// the `SessionsMiddleware`.
    @Test("Test Session Authentication Does Not Create Session When No Cookie Provided", .bug("https://github.com/vapor/vapor/pull/3372"))
    func testSessionNotCreatedWhenNoCookieProvided() async throws {
        struct Test: Authenticatable, SessionAuthenticatable {
            var sessionID: String
        }

        struct TestSessionAuthenticator: SessionAuthenticator {
            typealias User = Test

            func authenticate(sessionID: String, for request: Request) async throws {
                request.auth.login(Test(sessionID: sessionID))
            }
        }

        struct UserInfo: Content {
            var name: String
        }

        try await withApp { app in
            app.routes.grouped([
                app.sessions.middleware,
                TestSessionAuthenticator()
            ]).get("test") { req -> UserInfo in
                UserInfo(name: req.auth.get(Test.self)?.sessionID ?? "none")
            }

            try await app.testing().test(.get, "/test") { res in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == #"{"name":"none"}"#)
                #expect(res.headers[.setCookie] == nil)
            }
        }
    }

    @Test("Test Middleware Config with Existential")
    func middlewareConfigExistential() async {
        struct Test: Authenticatable {
            static func authenticator() -> any RequestAuthenticator {
                TestAuthenticator()
            }
            var name: String
        }

        struct TestAuthenticator: BearerAuthenticator {
            typealias User = Test

            func authenticate(bearer: BearerAuthorization, for request: Request) async throws {}
        }

        var config = Middlewares()
        config.use(Test.authenticator())
    }

    @Test("Test Concurrent Logins Are Not Lost")
    func concurrentLoginsAreNotLost() async throws {
        struct User: Authenticatable {
            var name: String
        }

        struct Token: Authenticatable {
            var value: String
        }

        // Each iteration uses a fresh request and logs each type in exactly once, so a login lost to
        // a race is observable. Repeated because the window is narrow — against the previous
        // storage-backed cache this loses roughly one in ten pairs.
        try await withApp { app in
            var lost = 0
            for _ in 0..<1_000 {
                let request = Request(application: app)

                await withTaskGroup(of: Void.self) { group in
                    group.addTask { request.auth.login(User(name: "Vapor")) }
                    group.addTask { request.auth.login(Token(value: "secret")) }
                }

                if request.auth.get(User.self) == nil || request.auth.get(Token.self) == nil {
                    lost += 1
                }
            }
            #expect(lost == 0, "\(lost) of 1000 concurrent login pairs lost one of the two instances")
        }
    }

    @Test("Test Multiple Types Can Be Authenticated Simultaneously")
    func multipleTypesAuthenticatedSimultaneously() async throws {
        struct User: Authenticatable {
            var name: String
        }

        struct Token: Authenticatable {
            var value: String
        }

        try await withApp { app in
            let request = Request(application: app)
            request.auth.login(User(name: "Vapor"))
            request.auth.login(Token(value: "secret"))

            #expect(request.auth.get(User.self)?.name == "Vapor")
            #expect(request.auth.get(Token.self)?.value == "secret")

            // Logging one type out must leave the other untouched.
            request.auth.logout(Token.self)
            #expect(request.auth.has(User.self))
            #expect(!request.auth.has(Token.self))
            #expect(request.auth.get(User.self)?.name == "Vapor")
        }
    }

    @Test("Test Logging In Again Replaces The Authenticated Instance")
    func loginReplacesExistingInstance() async throws {
        struct User: Authenticatable {
            var name: String
        }

        try await withApp { app in
            let request = Request(application: app)
            request.auth.login(User(name: "Vapor"))
            request.auth.login(User(name: "Vapor 2"))

            #expect(request.auth.get(User.self)?.name == "Vapor 2")

            // A single logout must be enough to clear it, i.e. the first login was replaced
            // rather than shadowed.
            request.auth.logout(User.self)
            #expect(!request.auth.has(User.self))
        }
    }

    @Test("Test Logout Clears The Authenticated Instance")
    func logoutClearsAuthenticatedInstance() async throws {
        struct User: Authenticatable {
            var name: String
        }

        try await withApp { app in
            let request = Request(application: app)

            // Nothing authenticated to begin with.
            #expect(!request.auth.has(User.self))
            #expect(request.auth.get(User.self) == nil)
            #expect(throws: Abort.self) { try request.auth.require(User.self) }

            request.auth.login(User(name: "Vapor"))
            #expect(request.auth.has(User.self))

            request.auth.logout(User.self)
            #expect(!request.auth.has(User.self))
            #expect(request.auth.get(User.self) == nil)
            #expect(throws: Abort.self) { try request.auth.require(User.self) }
        }
    }

    @Test("Test Login From Route Handler Is Persisted To The Session")
    func loginFromRouteHandlerIsPersistedToSession() async throws {
        struct Test: Authenticatable, SessionAuthenticatable {
            var sessionID: String
        }

        struct TestSessionAuthenticator: SessionAuthenticator {
            typealias User = Test

            func authenticate(sessionID: String, for request: Request) async throws {
                request.auth.login(Test(sessionID: sessionID))
            }
        }

        try await withApp { app in
            let routes = app.routes.grouped([
                app.sessions.middleware,
                TestSessionAuthenticator(),
            ])

            // Logs in from the handler, i.e. innermost — the session authenticator sits outside it
            // and only sees the login as the response unwinds.
            routes.get("login") { req -> String in
                req.auth.login(Test(sessionID: "Vapor"))
                return "logged in"
            }

            routes.get("me") { req -> String in
                req.auth.get(Test.self)?.sessionID ?? "none"
            }

            var sessionCookie: HTTPCookies.Value?
            try await app.testing().test(.get, "/login") { res async in
                #expect(res.status == .ok)
                if let cookie = res.headers.setCookie?["vapor-session"] {
                    sessionCookie = cookie
                } else {
                    Issue.record("No set cookie header")
                }
            }

            let cookie = try #require(sessionCookie)
            try await app.testing().test(.get, "/me", headers: [.cookie: cookie.serialize(name: "vapor-session")]) { res async in
                #expect(res.status == .ok)
                try #expect(await res.body.requireString() == "Vapor")
            }
        }
    }
}
