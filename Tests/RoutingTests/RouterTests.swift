import HTTP
import Routing
import XCTest

class RouterTests: XCTestCase {
    func testRouter() throws {
        let router = TrieRouter()

        router.on(.get, to: "hello", "world") { req in
            return try Response(body: "hello")
        }

        router.on(.get, to: "foo", "bar", "baz") { req in
            return try Response(body: "foo")
        }

        router.on(.get, to: "users", User.parameter, "comments") { req in
            return try Response(body: "users!")
        }

        let req = Request()

        do {
            var params = ParameterBag()
            let responder = router.route(
                path: ["GET", "foo", "bar", "baz"],
                parameters: &params
            )

            XCTAssertNotNil(responder)
            let res = try responder!.respond(to: req)
            try XCTAssertEqual(String(data: res.sync().body.data, encoding: .utf8), "foo")
        }

        do {
            var params = ParameterBag()
            let responder = router.route(
                path: ["GET", "hello", "world"],
                parameters: &params
            )

            XCTAssertNotNil(responder)
            let res = try responder!.respond(to: req)
            try XCTAssertEqual(String(data: res.sync().body.data, encoding: .utf8), "hello")
        }

        do {
            var params = ParameterBag()
            let responder = router.route(
                path: ["GET", "users", "bob", "comments"],
                parameters: &params
            )

            XCTAssertNotNil(responder)
            let res = try responder!.respond(to: req)
            try XCTAssertEqual(String(data: res.sync().body.data, encoding: .utf8), "users!")
            let bob = try params.next(User.self)
            XCTAssertEqual(bob.name, "bob")
        }
    }


    static let allTests = [
        ("testRouter", testRouter),
    ]
}

extension TrieRouter: SyncRouter { }

final class User: Parameter {
    static let uniqueSlug: String = "user"
    var name: String

    init(name: String) {
        self.name = name
    }

    static func make(for parameter: String) throws -> User {
        return User(name: parameter)
    }
}
