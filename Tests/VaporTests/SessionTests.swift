import XCTVapor
import XCTest
import Vapor
import NIOCore
import NIOHTTP1

final class SessionTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        app = try await Application.make(test)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    func testSessionDestroy() async throws {
        actor MockKeyedCache: AsyncSessionDriver {
            var ops: [String] = []
            init() { }

            func getOps() -> [String] {
                ops
            }
            
            func resetOps() {
                self.ops = []
            }

            func createSession(_ data: SessionData, for request: Request) async throws -> SessionID {
                self.ops.append("create \(data)")
                return .init(string: "a")
            }

            func readSession(_ sessionID: SessionID, for request: Request) async throws -> SessionData? {
                self.ops.append("read \(sessionID)")
                return SessionData()
            }

            func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) async throws -> SessionID {
                self.ops.append("update \(sessionID) to \(data)")
                return sessionID
            }

            func deleteSession(_ sessionID: SessionID, for request: Request) async throws {
                self.ops.append("delete \(sessionID)")
                return
            }
        }

        var cookie: HTTPCookies.Value?

        let cache = MockKeyedCache()
        app.sessions.use { _ in cache }
        let sessions = app.routes.grouped(app.sessions.middleware)
        sessions.get("set") { req -> String in
            req.session.data["foo"] = "bar"
            return "set"
        }
        sessions.get("del") { req  -> String in
            req.session.destroy()
            return "del"
        }

        try await app.testable().test(.GET, "/set") { res in
            XCTAssertEqual(res.body.string, "set")
            cookie = res.headers.setCookie?["vapor-session"]
            XCTAssertNotNil(cookie)
            let ops = await cache.ops
            XCTAssertEqual(ops, [
                #"create SessionData(storage: ["foo": "bar"])"#,
            ])
            await cache.resetOps()
        }

        XCTAssertEqual(cookie?.string, "a")

        var headers = HTTPHeaders()
        var cookies = HTTPCookies()
        cookies["vapor-session"] = cookie
        headers.cookie = cookies
        try await app.testable().test(.GET, "/del", headers: headers) { res in
            XCTAssertEqual(res.body.string, "del")
            let ops = await cache.ops
            XCTAssertEqual(ops, [
                #"read SessionID(string: "a")"#,
                #"delete SessionID(string: "a")"#
            ])
        }
    }

    func testInvalidCookie() throws {
        // Configure sessions.
        app.sessions.use(.memory)
        app.middleware.use(app.sessions.middleware)

        // Adds data to the request session.
        app.get("set") { req -> HTTPStatus in
            req.session.data["foo"] = "bar"
            return .ok
        }

        // Fetches data from the request session.
        app.get("get") { req -> String in
            guard let foo = req.session.data["foo"] else {
                throw Abort(.badRequest)
            }
            return foo
        }


        // Test accessing session with no cookie.
        try app.test(.GET, "get") { res in
            XCTAssertEqual(res.status, .badRequest)
        }

        // Test setting session with invalid cookie.
        var newCookie: HTTPCookies.Value?
        try app.test(.GET, "set", beforeRequest: { req in
            req.headers.cookie = ["vapor-session": "foo"]
        }, afterResponse: { res in
            // We should get a new cookie back.
            newCookie = res.headers.setCookie?["vapor-session"]
            XCTAssertNotNil(newCookie)
            // That is not the same as the invalid cookie we sent.
            XCTAssertNotEqual(newCookie?.string, "foo")
            XCTAssertEqual(res.status, .ok)
        })

        // Test accessing newly created session.
        try app.test(.GET, "get", beforeRequest: { req in
            // Pass cookie from previous request.
            req.headers.cookie = ["vapor-session": newCookie!]
        }, afterResponse: { res in
            // Session access should be successful.
            XCTAssertEqual(res.body.string, "bar")
            XCTAssertEqual(res.status, .ok)
        })
    }

    func testCookieQuotes() throws {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .cookie, value: #"foo= "+cookie/value" "#)
        XCTAssertEqual(headers.cookie?["foo"]?.string, "+cookie/value")
    }

    // https://github.com/vapor/vapor/issues/3620
    func testGH3620() async throws {
        actor SpySessionDriver: AsyncSessionDriver {
            var ops: [String] = []
            var sessions: [SessionID: SessionData] = [:]

            func resetOps() {
                self.ops = []
            }

            func createSession(_ data: SessionData, for request: Request) async throws -> SessionID {
                let id = SessionID(string: "a")
                self.sessions[id] = data
                self.ops.append("create")
                return id
            }

            func readSession(_ sessionID: SessionID, for request: Request) async throws -> SessionData? {
                self.ops.append("read \(sessionID.string)")
                return self.sessions[sessionID]
            }

            func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) async throws -> SessionID {
                self.sessions[sessionID] = data
                self.ops.append("update \(sessionID.string)")
                return sessionID
            }

            func deleteSession(_ sessionID: SessionID, for request: Request) async throws {
                self.sessions.removeValue(forKey: sessionID)
                self.ops.append("delete \(sessionID.string)")
            }
        }

        let driver = SpySessionDriver()
        self.app.sessions.use { _ in driver }
        let sessions = self.app.routes.grouped(self.app.sessions.middleware)
        sessions.get("untouched") { req -> String in
            return "\(req.hasSession)"
        }
        sessions.get("read") { req -> String in
            return req.session.data["user"] ?? "anonymous"
        }
        sessions.get("write") { req -> String in
            req.session.data["user"] = "alice"
            return "ok"
        }
        sessions.get("clear") { req -> String in
            req.session.data["user"] = nil
            return "ok"
        }

        // Case A: reading `req.session` without a cookie must not persist or set a cookie.
        try await self.app.testable().test(.GET, "/read") { res in
            XCTAssertEqual(res.body.string, "anonymous")
            XCTAssertNil(res.headers.first(name: .setCookie))
            let ops = await driver.ops
            let count = await driver.sessions.count
            XCTAssertEqual(ops, [])
            XCTAssertEqual(count, 0)
            await driver.resetOps()
        }

        // Case B: unknown cookie must expire instead of storing a new session or calling delete.
        var bogusHeaders = HTTPHeaders()
        bogusHeaders.cookie = ["vapor-session": "bogus"]
        try await self.app.testable().test(.GET, "/untouched", headers: bogusHeaders) { res in
            XCTAssertEqual(res.body.string, "false")
            let cleared = try XCTUnwrap(res.headers.setCookie?["vapor-session"])
            XCTAssertEqual(cleared.string, "")
            XCTAssertEqual(cleared.expires, HTTPCookies.Value.expired.expires)
            let ops = await driver.ops
            let count = await driver.sessions.count
            XCTAssertEqual(ops, ["read bogus"])
            XCTAssertEqual(count, 0)
            await driver.resetOps()
        }

        try await self.app.testable().test(.GET, "/read", headers: bogusHeaders) { res in
            XCTAssertEqual(res.body.string, "anonymous")
            let cleared = try XCTUnwrap(res.headers.setCookie?["vapor-session"])
            XCTAssertEqual(cleared.string, "")
            XCTAssertEqual(cleared.expires, HTTPCookies.Value.expired.expires)
            let ops = await driver.ops
            let count = await driver.sessions.count
            XCTAssertEqual(ops, ["read bogus"])
            XCTAssertEqual(count, 0)
            await driver.resetOps()
        }

        // Writing creates a session; clearing all keys on an existing session keeps and updates it.
        var validCookie: HTTPCookies.Value?
        try await self.app.testable().test(.GET, "/write") { res in
            XCTAssertEqual(res.body.string, "ok")
            validCookie = res.headers.setCookie?["vapor-session"]
            XCTAssertEqual(validCookie?.string, "a")
            let ops = await driver.ops
            XCTAssertEqual(ops, ["create"])
            await driver.resetOps()
        }

        var validHeaders = HTTPHeaders()
        var validCookies = HTTPCookies()
        validCookies["vapor-session"] = try XCTUnwrap(validCookie)
        validHeaders.cookie = validCookies
        try await self.app.testable().test(.GET, "/read", headers: validHeaders) { res in
            XCTAssertEqual(res.body.string, "alice")
            let ops = await driver.ops
            XCTAssertEqual(ops, ["read a", "update a"])
            await driver.resetOps()
        }

        try await self.app.testable().test(.GET, "/clear", headers: validHeaders) { res in
            XCTAssertEqual(res.body.string, "ok")
            XCTAssertEqual(res.headers.setCookie?["vapor-session"]?.string, "a")
            let ops = await driver.ops
            let stored = await driver.sessions[SessionID(string: "a")]
            XCTAssertEqual(ops, ["read a", "update a"])
            XCTAssertEqual(stored, SessionData())
        }
    }
}
