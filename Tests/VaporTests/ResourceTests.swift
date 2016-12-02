import XCTest
@testable import Vapor
import Fluent
import HTTP

class ResourceTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
        ("testOptions", testOptions)
    ]

    func testBasic() throws {
        let drop = Droplet()

        drop.middleware = []

        let user = try User(from: "Hi")
        let node = try user?.makeNode()
        XCTAssertEqual(node, .object(["name":"Hi"]))

        drop.resource("users", User.self) { users in
            users.index = { req in
                return "index"
            }

            users.new = { req in
                return "new"
            }

            users.show = { req, user in
                return "user \(user.name)"
            }
        }

        XCTAssertEqual(try drop.responseBody(for: .get, "users"), "index")
        XCTAssertEqual(try drop.responseBody(for: .get, "users/new"), "new")
        XCTAssertEqual(try drop.responseBody(for: .get, "users/bob"), "user bob")
        let errorResponse = try drop.responseBody(for: .get, "users/ERROR")
        print(errorResponse)
        XCTAssert(errorResponse.contains("Abort.notFound"))
    }

    func testOptions() throws {
        let drop = Droplet()

        drop.resource("users", User.self) { users in
            users.index = { req in
                return "index"
            }
            users.create = { req in
                return "create"
            }
        }

        XCTAssert(try drop.responseBody(for: .options, "users").contains("methods"))
        XCTAssert(try drop.responseBody(for: .options, "users/5").contains("methods"))
    }

}
