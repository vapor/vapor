#if compiler(>=5.5) && canImport(_Concurrency)
import XCTVapor

@available(macOS 10.15, iOS 15, watchOS 8, tvOS 15, *)
final class AsyncSessionTests: XCTestCase {
    func testSessionDestroy() throws {
        final class MockKeyedCache: AsyncSessionDriver {
            static var ops: [String] = []
            init() { }


            func createSession(_ data: SessionData, for request: Request) async throws -> SessionID {
                Self.ops.append("create \(data)")
                return .init(string: "a")
            }

            func readSession(_ sessionID: SessionID, for request: Request) async throws -> SessionData? {
                Self.ops.append("read \(sessionID)")
                return SessionData()
            }

            func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) async throws -> SessionID {
                Self.ops.append("update \(sessionID) to \(data)")
                return sessionID
            }

            func deleteSession(_ sessionID: SessionID, for request: Request) async throws {
                Self.ops.append("delete \(sessionID)")
                return
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
}
#endif
