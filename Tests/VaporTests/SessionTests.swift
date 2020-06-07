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
                var update = "update \(sessionID): "
                if data.anyUpdated { update += "no-op" }
                else {
                    if data.expiryChanged { update += "[expiration: \(data.expiration)] " }
                    if data.userStorageChanged { update += "[userStorage: \(data.storage)] " }
                    if data.appStorageChanged { update += "[appStorage: \(data.appStorage)]" }
                }
                Self.ops.append(update)
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
            XCTAssert(MockKeyedCache.ops.first!.contains(#"create SessionData(storage: ["foo": "bar"]"#))
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
        try! _benchmarkSessions(clients: 200, duration: 5, lifetime: 3, timeToUpdate: 1, mutateRate: 10, dataSize: 16, requestSize: 64)
    }
    
    func _benchmarkSessions(clients c: UInt16,       // number of clients to simulate
                            duration d: UInt8,       // duration in seconds of test
                            lifetime l: UInt8,       // cookie lifetime
                            timeToUpdate ttu: UInt8, // cookie expiration update threshold
                            mutateRate mr: UInt8,    // 0-100 - % rate of mutating session data
                            dataSize ds: UInt8,      // length of session data payload
                            requestSize rs: UInt16   // length of request body payload
                            ) throws {
        guard ttu <= l, l <= d, c != 0, (1...100).contains(mr) else { XCTFail("Check input parameters"); fatalError() }
        
        var actions: [SessionAction: Double] = [.create: 0, .destroy: 0, .updateInternal: 0, .updateAll: 0]
        let cookieName = "benchmark-sessions"
        var clientCookies: [HTTPCookies.Value?] = .init(repeating: nil, count: Int(c))
        var sleeping: [Int: Date] = [:]
    
        let app = Application(.testing)
        defer { app.shutdown() }
        // Configure sessions.
        app.sessions.use(.memory)
        app.sessions.configuration =
            .init(cookieName: cookieName,
                  cookieLifetime: UInt(l),
                  cookieTTU: UInt(ttu)
            ) { sessionID in
                HTTPCookies.Value(
                    string: sessionID.string,
                    expires: Date(timeIntervalSinceNow: Double(l)))
            }
        app.middleware.use(app.sessions.middleware)
        
        let start = Date()
        let datalock = Lock()
        var requests = 0
        var completed = Double(0)
        var set = Double(0)
        
        // Randomly mutates session data and returns a body, prepended with ! if no session data changed
        app.get("request") { req -> String in
            var dataUpdate = ""
            
            if req.headers.cookie?[cookieName] == nil {
                req.session.data["payload"] = generateGarbage(UInt32(ds)) // Always set data when no session exists
            } else if (1...100).randomElement()! <= mr {
                req.session.data["payload"] = generateGarbage(UInt32(ds)) // Or randomly decide whether to mutate
                datalock.withLock {
                    actions[.updateInternal] = actions[.updateInternal]! + 1
                }
            } else {
                dataUpdate = "!" // No session data was updated
            }
            return dataUpdate + generateGarbage(UInt32(rs))
        }
        
        while Date() < start + Double(d) {
            let interval = Date().timeIntervalSinceReferenceDate.distance(to: start.timeIntervalSinceReferenceDate)
            let progress = ((Double(d) - interval) / Double(d)) - 1.0
            // Start with 20% of clients, pace remaining 80% up to roughly 70% progress
            let clientMax = min(Int(Double(c) * (0.2 + ((1.0/0.7) * progress))), Int(c)-1)
            var clientMin = 0
            // 80% chance client choice is in the last half of the available client list instead of the full range
            if (1...100).randomElement()! <= 80 { clientMin = clientMax / 2 }
            
            var cookie: HTTPCookies.Value? = nil
            var client = 0
            var pickedOne = false
            // only wake a sleeper up if it's ready, but always wake one if we're low on awake clients
            datalock.lock()
            while !pickedOne {
                client = Int((clientMin...clientMax).randomElement()!)
                if sleeping.keys.count < clientMax / 2, let asleep = sleeping[client] {
                    if asleep < Date() {
                        sleeping[client] = nil
                        cookie = clientCookies[client]
                        pickedOne = true
                    }
                } else {
                    cookie = clientCookies[client]
                    if sleeping[client] != nil { sleeping[client] = nil }
                    pickedOne = true
                }
            }
            requests += 1
            datalock.unlock()
            
            try app.test(.GET, "request",
                beforeRequest: { req in
                    if cookie != nil { req.headers.cookie = [cookieName: cookie!] }
                },
                afterResponse: { res in
                    let responseCookie = res.headers.setCookie?[cookieName]
                    datalock.lock()
                    completed += 1
                    if responseCookie != nil { set += 1 }
                    // 1% chance this client will now go to sleep
                    if (1...100).randomElement()! <= 1 { sleeping[client] = Date(timeIntervalSinceNow: Double(l)) }
                    datalock.unlock()
                    
                    // if the request updated session data internally, old cookie, new cookie
                    switch (cookie, responseCookie) {
                        // Request didn't have a cookie and response didn't provide one - this is wrong
                        case (.none, .none): XCTFail("Cookie should have been set")
                        // A session with no modifications, inside threshold
                        case (.some, .none): break
                        // A new session
                        case (.none, .some(let rc)): datalock.withLock { clientCookies[client] = rc; actions[.create] = actions[.create]! + 1 }
                        // A refreshed session between TTU & lifetime
                        case (.some, .some(let rc)):
                            datalock.withLock {
                                if rc.expires! == Date(timeIntervalSince1970: 0) {
                                    clientCookies[client] = nil
                                    actions[.destroy] = actions[.destroy]! + 1
                                } else {
                                    actions[.updateAll] = actions[.updateAll]! + 1
                                }
                                // decrement internal update counter if session data was modified
                                if res.body.string.first! == "!" {
                                    actions[.updateInternal] = actions[.updateInternal]! - 1
                                }
                            }
                    }
                })
        }
    
        let unaffected = completed - set
        let p = [
            "set": (set, String(format: "%.2f%%", 100 * set / completed)),
            "empty": (unaffected, String(format: "%.2f%%", 100 * unaffected / completed)),
            "internalOnly": (actions[.updateInternal]!, String(format: "%.2f%%", 100 * actions[.updateInternal]! / completed)),
            "unchanged": (unaffected - actions[.updateInternal]!, String(format: "%.2f%%", 100 * (unaffected - actions[.updateInternal]!) / completed)),
            "created": (actions[.create]!, String(format: "%.2f%%", 100*actions[.create]!/completed)),
            "destroyed": (actions[.destroy]!, String(format: "%.2f%%", 100*actions[.destroy]!/completed)),
            "refreshed": (actions[.updateAll]!, String(format: "%.2f%%", 100*actions[.updateAll]!/completed)),
        ]
        
        print("""
        Completed \(requests) requests:
        - \(Int(p["empty"]!.0)) (\(p["empty"]!.1)) needed no cookie return...
            - \(Int(p["internalOnly"]!.0)) (\(p["internalOnly"]!.1)) mutated session data inside TTU
            - \(Int(p["unchanged"]!.0)) (\(p["unchanged"]!.1)) had no session changes inside TTU
        - \(Int(p["set"]!.0)) (\(p["set"]!.1)) returned a cookie...
            - \(Int(p["created"]!.0)) (\(p["created"]!.1)) from creating new sessions
            - \(Int(p["destroyed"]!.0)) (\(p["destroyed"]!.1)) from destroying sessions
            - \(Int(p["refreshed"]!.0)) (\(p["refreshed"]!.1)) from refreshing past TTU but before lifetime
        """
        )
    }
}

fileprivate enum SessionAction: Hashable {
    case create
    case destroy
    case updateInternal
    case updateAll
}

fileprivate func generateGarbage(_ length: UInt32) -> String {
    var stream = String()
    let chars: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890!@#$%^&*()_{}[]|~` "
    for _ in 0..<length {
        stream.append(chars.randomElement()!)
    }
    return stream
}
