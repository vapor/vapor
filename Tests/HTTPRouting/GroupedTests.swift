import XCTest
import Engine
import HTTPRouting

class GroupedTests: XCTestCase {
    static var allTests = [
        ("testBasic", testBasic),
        ("testVariadic", testVariadic),
        ("testChained", testChained),
        ("testHost", testHost)
    ]

    func testBasic() throws {
        let router = Router()

        let users = router.grouped("users")
        users.add(.get, ":id") { request in
            return "show"
        }

        let request = HTTPRequest(method: .get, path: "users/5")
        let bytes = try request.bytes(running: router)

        XCTAssertEqual(bytes, "show".bytes)
        XCTAssertEqual(request.parameters["id"], "5")
    }

    func testVariadic() throws {
        let router = Router()

        let users = router.grouped("users", "devices", "etc")
        users.add(.get, ":id") { request in
            return "show"
        }

        let request = HTTPRequest(method: .get, path: "users/devices/etc/5")
        let bytes = try request.bytes(running: router)

        XCTAssertEqual(bytes, "show".bytes)
        XCTAssertEqual(request.parameters["id"], "5")
    }

    func testChained() throws {
        let router = Router()

        let users = router.grouped("users", "devices", "etc").grouped("even", "deeper")
        users.add(.get, ":id") { request in
            return "show"
        }

        let request = HTTPRequest(method: .get, path: "users/devices/etc/even/deeper/5")
        let bytes = try request.bytes(running: router)

        XCTAssertEqual(bytes, "show".bytes)
        XCTAssertEqual(request.parameters["id"], "5")
    }

    func testHost() throws {
        let router = Router()

        let host = router.grouped(host: "192.168.0.1")
        host.add(.get, "host-only") { request in
            return "host"
        }

        router.add(.get, "host-only") { req in
            return "nothost"
        }

        let request = HTTPRequest(method: .get, path: "host-only", host: "192.168.0.1")
        let bytes = try request.bytes(running: router)

        XCTAssertEqual(bytes, "host".bytes)
    }
}
