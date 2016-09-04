import XCTest
import HTTP
import Routing
import URI

extension String: Swift.Error {}

class RouterTests: XCTestCase {
    static var allTests = [
        ("testRouter", testRouter),
        ("testWildcardMethod", testWildcardMethod),
        ("testWildcardHost", testWildcardHost),
        ("testHostMatch", testHostMatch),
        ("testMiss", testMiss),
        ("testWildcardPath", testWildcardPath),
        ("testParameters", testParameters),
        ("testEmpty", testEmpty),
        ("testNoHostWildcard", testNoHostWildcard)
    ]

    func testRouter() throws {
        let router = Router<RequestHandler>()
        router.register(path: ["0.0.0.0", "GET", "hello"]) { request in
            return Response(body: "Hello, World!")
        }

        let request = try Request(method: .get, uri: "http://0.0.0.0/hello")
        let handler = router.route(request)
        XCTAssert(handler != nil)
        let response = try handler?(request).makeResponse()
        XCTAssert(response?.body.bytes?.string == "Hello, World!")
    }

    func testWildcardMethod() throws {
        let router = Router<RequestHandler>()
        router.register(path: ["0.0.0.0", "*", "hello"]) { request in
            return Response(body: "Hello, World!")
        }

        let method: [HTTP.Method] = [.get, .post, .put, .patch, .delete, .trace, .head, .options]
        try method.forEach { method in
            let request = try Request(method: method, uri: "http://0.0.0.0/hello")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse()
            XCTAssert(response?.body.bytes?.string == "Hello, World!")
        }
    }

    func testWildcardHost() throws {
        let router = Router<RequestHandler>()
        router.register(path: ["*", "GET", "hello"]) { request in
            return Response(body: "Hello, World!")
        }

        let hosts: [String] = ["0.0.0.0", "chat.app.com", "[255.255.255.255.255]", "slack.app.com"]
        try hosts.forEach { host in
            let request = try Request(method: .get, uri: "http://\(host)/hello")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse()
            XCTAssert(response?.body.bytes?.string == "Hello, World!")
        }
    }

    func testHostMatch() throws {
        let router = Router<RequestHandler>()

        let hosts: [String] = ["0.0.0.0", "chat.app.com", "[255.255.255.255.255]", "slack.app.com"]
        hosts.forEach { host in
            router.register(path: [host, "GET", "hello"]) { request in
                return Response(body: "Host: \(host)")
            }
        }

        try hosts.forEach { host in
            let request = try Request(method: .get, uri: "http://\(host)/hello")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse()
            XCTAssert(response?.body.bytes?.string == "Host: \(host)")
        }
    }

    func testMiss() throws {
        let router = Router<RequestHandler>()
        router.register(path: ["0.0.0.0", "*", "hello"]) { request in
            XCTFail("should not be found, wrong host")
            return Response(body: "[fail]")
        }

        let request = try Request(method: .get, uri: "http://[255.255.255.255.255]/hello")
        let handler = router.route(request)
        XCTAssert(handler == nil)
    }

    func testWildcardPath() throws {
        let router = Router<RequestHandler>()
        router.register(path: ["0.0.0.0", "GET", "hello", "*"]) { request in
            return Response(body: "Hello, World!")
        }

        let paths: [String] = [
            "hello",
            "hello/zero",
            "hello/extended/path",
            "hello/very/extended/path.pdf"
        ]

        try paths.forEach { path in
            let request = try Request(method: .get, uri: "http://0.0.0.0/\(path)")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse()
            XCTAssert(response?.body.bytes?.string == "Hello, World!")
        }
    }

    func testParameters() throws {
        let router = Router<RequestHandler>()
        router.register(path: ["0.0.0.0", "GET", "hello", ":name", ":age"]) { request in
            guard let name = request.parameters["name"]?.string else { throw "missing param: name" }
            guard let age = request.parameters["age"]?.int else { throw "missing or invalid param: age" }
            return Response(body: "Hello, \(name) aged \(age).")
        }

        let namesAndAges: [(String, Int)] = [
            ("a", 12),
            ("b", 42),
            ("c", 200),
            ("d", 1)
        ]

        try namesAndAges.forEach { name, age in
            let request = try Request(method: .get, uri: "http://0.0.0.0/hello/\(name)/\(age)")
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse()
            XCTAssert(response?.body.bytes?.string == "Hello, \(name) aged \(age).")
        }
    }

    func testEmpty() throws {
        let router = Router<RequestHandler>()
        router.register(path: []) { request in
            return Response(body: "Hello, Empty!")
        }

        let empties: [String] = ["", "/"]
        try empties.forEach { emptypath in
            let uri = URI(scheme: "http", host: "0.0.0.0", path: emptypath)
            let request = try Request(method: .get, uri: uri)
            let handler = router.route(path: [], with: request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse()
            XCTAssert(response?.body.bytes?.string == "Hello, Empty!")
        }
    }

    func testNoHostWildcard() throws {
        let router = Router<RequestHandler>()
        router.register(path: ["*", "GET"]) { request in
            return Response(body: "Hello, World!")
        }

        let uri = URI(
            scheme: "",
            host: ""
        )
        let request = try Request(method: .get, uri: uri)
        let handler = router.route(request)
        XCTAssert(handler != nil)
        let response = try handler?(request).makeResponse()
        XCTAssert(response?.body.bytes?.string == "Hello, World!")
    }
}
