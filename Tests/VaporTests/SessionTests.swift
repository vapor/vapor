import VaporTesting
import Testing
import Vapor
import NIOCore
import HTTPTypes

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

            try await app.testing().test(.get, "/set") { res in
                #expect(res.body.string == "set")
                cookie = res.headers.setCookie?["vapor-session"]
                #expect(cookie != nil)
                let ops = await cache.ops
                #expect(ops == [
                    #"create SessionData(storage: ["foo": "bar"])"#,
                ])
                await cache.resetOps()
            }

            #expect(cookie?.string == "a")

            var headers = HTTPFields()
            var cookies = HTTPCookies()
            cookies["vapor-session"] = cookie
            headers.cookie = cookies
            try await app.testing().test(.get, "/del", headers: headers) { res in
                #expect(res.body.string == "del")
                let ops = await cache.ops
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
            try await app.testing().test(.get, "get") { res in
                #expect(res.status == .badRequest)
            }

            // Test setting session with invalid cookie.
            var newCookie: HTTPCookies.Value?
            try await app.testing().test(.get, "set", beforeRequest: { req in
                req.headers.cookie = ["vapor-session": "foo"]
            }, afterResponse: { res in
                // We should get a new cookie back.
                newCookie = res.headers.setCookie?["vapor-session"]
                #expect(newCookie != nil)
                // That is not the same as the invalid cookie we sent.
                #expect(newCookie?.string != "foo")
                #expect(res.status == .ok)
            })

            // Test accessing newly created session.
            try await app.testing().test(.get, "get", beforeRequest: { req in
                // Pass cookie from previous request.
                req.headers.cookie = ["vapor-session": newCookie!]
            }, afterResponse: { res in
                // Session access should be successful.
                #expect(res.body.string == "bar")
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Test cookie handles quotes correctly")
    func cookieQuotes() throws {
        var headers = HTTPFields()
        headers.replaceOrAdd(name: .cookie, value: #"foo= "+cookie/value" "#)
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
