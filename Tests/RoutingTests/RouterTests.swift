import Async
import HTTP
import Bits
import Routing
import XCTest

class RouterTests: XCTestCase {
    func testRouter() throws {
        let router = TrieRouter()
        
        let a = BasicResponder { req in
            return try Future(Response(body: "hello"))
        }
        let ra = Route(
            method: .get,
            path: ["hello", "world"].makePathComponents(),
            responder: a
        )
        router.register(route: ra)

        let b = BasicResponder { req in
            return try Future(Response(body: "foo"))
        }
        let rb = Route(
            method: .get,
            path: ["foo", "bar", "baz"].makePathComponents(),
            responder: b
        )
        router.register(route: rb)

        let c = BasicResponder { req in
            return try req.parameters.next(User.self).map { bob in
                XCTAssertEqual(bob.name, "bob")
                return try Response(body: "users!")
            }
        }
        let rc = Route(
            method: .get,
            path: ["users", User.parameter, "comments"].makePathComponents(),
            responder: c
        )
        router.register(route: rc)

        do {
            let request = Request(method: .get, uri: URI(path: "/foo/bar/baz"))
            let responder = router.route(request: request)

            XCTAssertNotNil(responder)
            
            let res = try responder?.respond(to: request).blockingAwait()
            
            try res?.body.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: res!.body.count ?? 0)
                XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "foo")
            }
        }

        do {
            let request = Request(method: .get, uri: URI(path: "/hello/world"))
            let responder = router.route(request: request)

            XCTAssertNotNil(responder)
            
            let res = try responder?.respond(to: request).blockingAwait()
            try res?.body.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: res!.body.count ?? 0)
                XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "hello")
            }
        }

        do {
            let request = Request(method: .get, uri: URI(path: "/users/bob/comments"))
            let responder = router.route(request: request)

            XCTAssertNotNil(responder)
            
            let res = try responder?.respond(to: request).blockingAwait()
            try res?.body.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: res!.body.count ?? 0)
                XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "users!")
            }
        }
    }


    static let allTests = [
        ("testRouter", testRouter),
    ]
}

final class User: Parameter {
    static let uniqueSlug: String = "user"
    var name: String

    init(name: String) {
        self.name = name
    }

    static func make(for parameter: String, in request: Request) throws -> Future<User> {
        return Future(User(name: parameter))
    }
}
