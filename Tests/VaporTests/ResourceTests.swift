import XCTest
@testable import Vapor
import Fluent
import HTTP

class ResourceTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
        ("testOptions", testOptions),
        ("testBackwardsCompatibility", testBackwardsCompatibility),
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

            users.edit = { req, user in
                return "edit \(user.name)"
            }
        }

        XCTAssertEqual(try drop.responseBody(for: .get, "users"), "index")
        XCTAssertEqual(try drop.responseBody(for: .get, "users/new"), "new")
        XCTAssertEqual(try drop.responseBody(for: .get, "users/bob"), "user bob")
        XCTAssertEqual(try drop.responseBody(for: .get, "users/bob/edit"), "edit bob")
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

            users.show = { req, user in
                return "user \(user.name)"
            }
        }

        XCTAssert(try drop.responseBody(for: .options, "users").contains("methods"))
        XCTAssert(try drop.responseBody(for: .options, "users/5").contains("methods"))
    }

    func testBackwardsCompatibility() {
        func simple(request: Request) throws -> ResponseRepresentable {
            throw Abort.notFound
        }

        func item(request: Request, user: User) throws -> ResponseRepresentable {
            throw Abort.notFound
        }

        let resource = Resource(index: simple,
                                store: simple,
                                show: item,
                                replace: item,
                                modify: item,
                                destroy: item,
                                clear: simple,
                                aboutItem: item,
                                aboutMultiple: simple)

        XCTAssertNotNil(resource.index)
        XCTAssertNotNil(resource.create)
        XCTAssertNotNil(resource.show)
        XCTAssertNotNil(resource.replace)
        XCTAssertNotNil(resource.update)
        XCTAssertNotNil(resource.update)
        XCTAssertNotNil(resource.destroy)
        XCTAssertNotNil(resource.clear)
        XCTAssertNotNil(resource.aboutItem)
        XCTAssertNotNil(resource.aboutMultiple)
    }

}
