import XCTVapor
import XCTest
import Vapor
import NIOHTTP1

final class AsyncSessionTests: XCTestCase {
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
}
