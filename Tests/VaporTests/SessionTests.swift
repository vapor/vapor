import XCTVapor

final class SessionTests: XCTestCase {
    func testSessionDestroy() throws {
        final class MockKeyedCache: SessionDriver {
            static var ops: [String] = []
            init() { }


            func createSession(_ data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
                Self.ops.append("create \(data)")
                return request.eventLoop.makeSucceededFuture(.init(string: "a"))
            }

            func readSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<SessionData?> {
                Self.ops.append("read \(sessionID)")
                return request.eventLoop.makeSucceededFuture(SessionData())
            }

            func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
                Self.ops.append("update \(sessionID) to \(data)")
                return request.eventLoop.makeSucceededFuture(sessionID)
            }

            func deleteSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<Void> {
                Self.ops.append("delete \(sessionID)")
                return request.eventLoop.makeSucceededFuture(())
            }
        }

        var cookie: HTTPCookies.Value?

        let app = Application()
        defer { app.shutdown() }

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

        try app.testable().test(.GET, "/set") { res in
            XCTAssertEqual(res.body.string, "set")
            cookie = res.headers.setCookie?["vapor-session"]
            XCTAssertNotNil(cookie)
            XCTAssertEqual(MockKeyedCache.ops, [
                #"create SessionData(storage: ["foo": "bar"])"#,
            ])
            MockKeyedCache.ops = []
        }

        XCTAssertEqual(cookie?.string, "a")

        var headers = HTTPHeaders()
        var cookies = HTTPCookies()
        cookies["vapor-session"] = cookie
        headers.cookie = cookies
        try app.testable().test(.GET, "/del", headers: headers) { res in
            XCTAssertEqual(res.body.string, "del")
            XCTAssertEqual(MockKeyedCache.ops, [
                #"read SessionID(string: "a")"#,
                #"delete SessionID(string: "a")"#
            ])
        }
    }

    func testInvalidCookie() throws {
        let app = Application(.detect(default: .testing))
        defer { app.shutdown() }

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
}
