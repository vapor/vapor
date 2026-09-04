import VaporTesting
import Testing
import Vapor
import NIOCore
import HTTPTypes
import RoutingKit

@Suite("Session Tests")
struct SessionTests {
    @Test("Test destroying a session")
    func sessionDestroy() async throws {
        try await withApp { app in
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

            try await app.testing { client in
                let setRes = try await client.get("/set")
                try #expect(await setRes.body.requireString() == "set")
                cookie = setRes.headers.setCookie?["vapor-session"]
                #expect(cookie != nil)
                var ops = await cache.ops
                #expect(ops == [
                    #"create SessionData(storage: ["foo": "bar"])"#,
                ])
                await cache.resetOps()
                #expect(cookie?.string == "a")

                var headers = HTTPFields()
                var cookies = HTTPCookies()
                cookies["vapor-session"] = cookie
                headers.cookie = cookies

                let delRes = try await client.get("/del", headers: headers)
                try #expect(await delRes.body.requireString() == "del")
                ops = await cache.ops
                #expect(ops == [
                    #"read SessionID(string: "a")"#,
                    #"delete SessionID(string: "a")"#
                ])
            }
        }
    }

    @Test("Test using invalid cookie")
    func testInvalidCookie() async throws {
        try await withApp { app in
            // Configure sessions.
            app.sessions.use(.memory)
            app.middleware.use(app.sessions.middleware)

            // Adds data to the request session.
            app.get("set") { req -> HTTPResponse.Status in
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

            try await app.testing { client in
                // Test accessing session with no cookie.
                let getRes = try await client.get("get")
                #expect(getRes.status == .badRequest)

                // Test setting session with invalid cookie.
                var newCookie: HTTPCookies.Value?
                let setRes = try await client.get("set") { req in
                    req.headers.cookie = ["vapor-session": "foo"]
                }
                // We should get a new cookie back.
                newCookie = setRes.headers.setCookie?["vapor-session"]
                #expect(newCookie != nil)
                // That is not the same as the invalid cookie we sent.
                #expect(newCookie?.string != "foo")
                #expect(setRes.status == .ok)

                // Test accessing newly created session.
                let get2Res = try await client.get("get") { req in
                    req.headers.cookie = ["vapor-session": newCookie!]
                }
                // Session access should be successful.
                try #expect(await get2Res.body.requireString() == "bar")
                #expect(get2Res.status == .ok)
            }
        }
    }

    @Test("Test cookie handles quotes correctly")
    func cookieQuotes() throws {
        var headers = HTTPFields()
        headers[.cookie] = #"foo= "+cookie/value" "#
        #expect(headers.cookie?["foo"]?.string == "+cookie/value")
    }
}

actor MockKeyedCache: SessionDriver {
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
