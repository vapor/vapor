import XCTest
import Engine
import HTTPRouting

class GroupTests: XCTestCase {
    static var allTests = [
        ("testBasic", testBasic),
        ("testVariadic", testVariadic),
        ("testHost", testHost),
        ("testHostMiss", testHostMiss)
    ]

    func testBasic() throws {
        let router = Router()

        router.group("users") { users in
            users.add(.get, ":id") { request in
                return "show"
            }
        }

        let request = HTTPRequest(method: .get, path: "users/5")
        let bytes = try request.bytes(running: router)

        XCTAssertEqual(bytes, "show".bytes)
        XCTAssertEqual(request.parameters["id"], "5")
    }

    func testVariadic() throws {
        let router = Router()

        router.group("users", "devices", "etc") { users in
            users.add(.get, ":id") { request in
                return "show"
            }
        }
        let request = HTTPRequest(method: .get, path: "users/devices/etc/5")
        let bytes = try request.bytes(running: router)

        XCTAssertEqual(bytes, "show".bytes)
        XCTAssertEqual(request.parameters["id"], "5")
    }

    func testHost() throws {
        let router = Router()

        router.group(host: "192.168.0.1") { host in
            host.add(.get, "host-only") { request in
                return "host"
            }
        }
        router.add(.get, "host-only") { req in
            return "nothost"
        }

        let request = HTTPRequest(method: .get, path: "host-only", host: "192.168.0.1")
        let bytes = try request.bytes(running: router)

        XCTAssertEqual(bytes, "host".bytes)
    }

    func testHostMiss() throws {
        let router = Router()

        router.group(host: "192.168.0.1") { host in
            host.add(.get, "host-only") { request in
                return "host"
            }
        }
        router.add(.get, "host-only") { req in
            return "nothost"
        }

        let request = HTTPRequest(method: .get, path: "host-only", host: "BADHOST")
        let bytes = try request.bytes(running: router)

        XCTAssertEqual(bytes, "nothost".bytes)
    }
}
