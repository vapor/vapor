import VaporTesting
import Testing
import Vapor
import HTTPTypes
import RoutingKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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

    @Test("hasSession is false until the session is used")
    func testHasSessionIsFalseUntilUsed() async throws {
        try await withApp { app in
            app.sessions.use(.memory)
            let sessions = app.routes.grouped(app.sessions.middleware)
            // Reported before the session is touched, so reading it here must not create one.
            sessions.get("untouched") { req -> String in "\(req.hasSession)" }
            sessions.get("touched") { req -> String in
                req.session.data["foo"] = "bar"
                return "\(req.hasSession)"
            }

            try await app.testing { client in
                try #expect(await client.get("/untouched").body.requireString() == "false")
                try #expect(await client.get("/touched").body.requireString() == "true")
            }
        }
    }

    @Test("hasSession is true when a stored session is restored from a cookie")
    func testHasSessionWithExistingCookie() async throws {
        try await withApp { app in
            app.sessions.use(.memory)
            let sessions = app.routes.grouped(app.sessions.middleware)
            sessions.get("set") { req -> String in
                req.session.data["foo"] = "bar"
                return "set"
            }
            // Deliberately does not touch `req.session`: the middleware restoring the session from
            // the cookie is what makes `hasSession` true here.
            sessions.get("check") { req -> String in "\(req.hasSession)" }

            try await app.testing { client in
                let setRes = try await client.get("/set")
                let cookie = try #require(setRes.headers.setCookie?["vapor-session"])

                let checkRes = try await client.get("/check") { req in
                    req.headers.cookie = ["vapor-session": cookie]
                }
                try #expect(await checkRes.body.requireString() == "true")
            }
        }
    }

    @Test("Session data survives a round trip")
    func testSessionDataRoundTrip() async throws {
        try await withApp { app in
            app.sessions.use(.memory)
            let sessions = app.routes.grouped(app.sessions.middleware)
            sessions.get("set") { req -> String in
                req.session.data["name"] = "Vapor"
                req.session.data["colour"] = "blue"
                return "set"
            }
            sessions.get("get") { req -> String in
                let name = req.session.data["name"] ?? "none"
                let colour = req.session.data["colour"] ?? "none"
                return "\(name)/\(colour)"
            }

            try await app.testing { client in
                let setRes = try await client.get("/set")
                let cookie = try #require(setRes.headers.setCookie?["vapor-session"])

                let getRes = try await client.get("/get") { req in
                    req.headers.cookie = ["vapor-session": cookie]
                }
                try #expect(await getRes.body.requireString() == "Vapor/blue")
            }
        }
    }

    @Test("Destroying a session expires the client's cookie")
    func testDestroyExpiresCookie() async throws {
        try await withApp { app in
            app.sessions.use(.memory)
            let sessions = app.routes.grouped(app.sessions.middleware)
            sessions.get("set") { req -> String in
                req.session.data["foo"] = "bar"
                return "set"
            }
            sessions.get("del") { req -> String in
                req.session.destroy()
                return "del"
            }

            try await app.testing { client in
                let setRes = try await client.get("/set")
                let cookie = try #require(setRes.headers.setCookie?["vapor-session"])

                let delRes = try await client.get("/del") { req in
                    req.headers.cookie = ["vapor-session": cookie]
                }
                // `destroy()` clears `isValid`, so the middleware replaces the cookie with an
                // expired one rather than reissuing it.
                let cleared = try #require(delRes.headers.setCookie?["vapor-session"])
                #expect(cleared.string == "")
                #expect(cleared.expires == Date(timeIntervalSince1970: 0))
            }
        }
    }

    @Test("A Session exposes the id and data it was created with")
    func testSessionAccessors() throws {
        let session = Session(id: SessionID(string: "abc"), data: SessionData(initialData: ["foo": "bar"]))
        #expect(session.id == SessionID(string: "abc"))
        #expect(session.data["foo"] == "bar")

        session.id = SessionID(string: "xyz")
        session.data["foo"] = "baz"
        #expect(session.id == SessionID(string: "xyz"))
        #expect(session.data["foo"] == "baz")

        #expect(Session().id == nil)
        #expect(Session().data == SessionData())
    }

    @Test("Concurrent access to a session is serialised", .timeLimit(.minutes(1)))
    func testConcurrentSessionAccess() async throws {
        let session = Session()
        let ids = (0..<200).map { SessionID(string: "id-\($0)") }

        // Every field sits behind one lock, so concurrent readers and writers must not race.
        // This does not claim that compound mutations are atomic: `data["k"] = v` reads through the
        // getter and writes back through the setter, so concurrent updates to it can still be lost.
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { session.id = id }
                group.addTask { _ = session.id }
                group.addTask { _ = session.data }
            }
        }

        let final = try #require(session.id)
        #expect(ids.contains(final), "the surviving id must be one that was actually written")
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
