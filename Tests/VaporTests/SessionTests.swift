import XCTVapor

final class SessionTests: XCTestCase {
    func testSessionDestroy() throws {
        final class MockKeyedCache: SessionDriver {
            static var ops: [String] = []
            init() { }


            func createSession(_ data: SessionData, expiring: Date, for request: Request) -> EventLoopFuture<SessionID> {
                Self.ops.append("create \(data)")
                return request.eventLoop.makeSucceededFuture(.init(string: "a"))
            }

            func readSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<(SessionData, Date)?> {
                Self.ops.append("read \(sessionID)")
                return request.eventLoop.makeSucceededFuture((SessionData(), .distantFuture))
            }

            func updateSession(_ sessionID: SessionID, to data: SessionData?, expiring: Date?, for request: Request) -> EventLoopFuture<SessionID> {
                switch (data, expiring) {
                    case (.none, .none): Self.ops.append("update \(sessionID) - no-op")
                    case (.some, .none): Self.ops.append("update \(sessionID) data to \(data!)")
                    case (.none, .some): Self.ops.append("update \(sessionID) expiration to \(expiring!)")
                    case (.some, .some): Self.ops.append("update \(sessionID) to \(data!) expiring \(expiring!)")
                }
                return request.eventLoop.makeSucceededFuture(sessionID)
            }

            func deleteSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<Void> {
                Self.ops.append("delete \(sessionID)")
                return request.eventLoop.makeSucceededFuture(())
            }
            
            func deleteExpiredSessions(before: Date, on request: Request) -> EventLoopFuture<Void> {
                Self.ops.append("delete sessions expiring before \(before)")
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
                #"create SessionData(storage: ["foo": "bar"], update: true)"#,
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
        let app = Application(.testing)
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
    
    
    func testBenchmarks() {
        try! _benchmarkSessions(clients: 200, duration: 10, lifetime: 3, timeToUpdate: 1, mutateRate: 10, dataSize: 16, requestSize: 64)
    }
    
    func _benchmarkSessions(clients c: UInt16,        // number of clients to simulate
                            duration d: UInt8,       // duration in seconds of test
                            lifetime l: UInt8,       // cookie lifetime
                            timeToUpdate ttu: UInt8, // cookie expiration update threshold
                            mutateRate mr: UInt8,    // 0-100 - % rate of mutating session data
                            dataSize ds: UInt8,      // length of session data payload
                            requestSize rs: UInt16   // length of request body payload
                            ) throws {
            guard ttu <= l, l <= d, c != 0, (0...100).contains(mr) else
                { XCTFail("Check input parameters"); fatalError("invalid input") }
            
            var actions: [SessionAction: Int] =
                [.create: 0, .destroy: 0, .read: 0,
                 .updateNothing: 0, .updateExpiry: 0,
                 .updateData: 0, .updateAll: 0]
            let cookieName = "benchmark-sessions"
            var clientCookies: [HTTPCookies.Value?] = .init(repeating: nil, count: Int(c))
            
            let app = Application(.testing)
            
            defer { app.shutdown() }

            // Configure sessions.
            app.sessions.use(.memory)
            app.sessions.configuration = .init(
                cookieName: cookieName,
                cookieLifetime: UInt(l),
                cookieTTU: UInt(ttu)
                )
                { sessionID in
                    return HTTPCookies.Value(
                        string: sessionID.string,
                        expires: Date(timeIntervalSinceNow: Double(l)),
                        maxAge: nil,
                        domain: nil,
                        path: "/",
                        isSecure: false,
                        isHTTPOnly: false,
                        sameSite: nil)
                }
            app.middleware.use(app.sessions.middleware)
            
            let start = Date()
            let datalock = Lock()
            var requests = 0
            var completed = 0
            
            
            // Randomly mutates session data and returns a body.
            app.get("request") { req -> String in
                if req.headers.cookie?[cookieName] == nil {
                    req.session.data["payload"] = generateGarbage(UInt32(ds)) // Always set data when no session exists
                } else if (0...100).randomElement()! <= mr {
                    req.session.data["payload"] = generateGarbage(UInt32(ds)) // Or randomly decide whether to mutate
                    datalock.withLock {
                        actions[.updateData] = actions[.updateData]! + 1
                    }
                }
                return generateGarbage(UInt32(rs))
            }
            
            while Date() < start + Double(d) {
                let progress: Double = ((Double(d) - (Date().distance(to: start))) / Double(d)) - 1.0
                // Start with 20% of clients, pace remaining 80% up to roughly 90% progress
                let clientMax = min(Int(Double(c) * (0.2 + (0.9 * progress))), Int(c)-1)
                var clientMin = 0
                // 90% chance client choice is in the last half of the available client list instead of the full range
                if (0..<100).randomElement()! < 90 { clientMin = clientMax / 2 }
                
                let client = Int((clientMin...clientMax).randomElement()!)
                
                let cookie: HTTPCookies.Value?
                datalock.lock()
                requests += 1
                cookie = clientCookies[client]
                datalock.unlock()
                try app.test(.GET, "request",
                    beforeRequest: { req in
                        if cookie != nil {
                            req.headers.cookie = [cookieName: cookie!]
                        }
                    },
                    afterResponse: { res in
                        let responseCookie = res.headers.setCookie?[cookieName]
                        
                        switch (cookie, responseCookie) {
                            // Request didn't have a cookie and response didn't provide one - this is wrong
                            case (.none, .none): XCTFail("Cookie should have been set")
                            // Request provided a cookie, we didn't get one back - this is normal case before threshold
                            case (.some, .none): datalock.withLock { completed += 1 }
                            // Request didn't have a cookie, response provided one - new session
                            case (.none, .some(let rc)):
                                datalock.withLock {
                                    actions[.create] = actions[.create]! + 1
                                    clientCookies[client] = rc;
                                    completed += 1
                                }
                            // Request provided a cookie and response provided one - this is a cookie either expired or past threshold
                            case (.some, .some(let rc)):
                                // Expired cookie - mark destroyed, destroy client cookie store
                                if rc.expires! < Date() {
                                    datalock.withLock {
                                        actions[.destroy] = actions[.destroy]! + 1
                                        clientCookies[client] = nil
                                        completed += 1
                                    }
                                }
                                // Updated cookie - refresh the cookie store
                                else {
                                    datalock.withLock {
                                        actions[.updateExpiry] = actions[.updateExpiry]! + 1
                                        clientCookies[client] = rc
                                        completed += 1
                                    }
                                }
                        }
                    })
            }
            
            print("Completed: \(completed) of \(requests): \(actions[.create]!) cookies created, \(actions[.updateData]!) data updated, \(actions[.updateExpiry]!) expiration refreshed, \(actions[.destroy]!) expired")
        }
    }

fileprivate enum SessionAction: Hashable {
    case create
    case read
    case destroy
    case updateNothing
    case updateAll
    case updateData
    case updateExpiry
}

fileprivate func generateGarbage(_ length: UInt32) -> String {
    var stream = String()
    let chars: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890!@#$%^&*()_{}[]|~` "
    for _ in 0..<length {
        stream.append(chars.randomElement()!)
    }
    return stream
}
