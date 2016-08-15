import XCTest
import HTTP
import Routing
import URI

class RouteTests: XCTestCase {
    static var allTests = [
        ("testRoute", testRoute),
        ("testRouteParams", testRouteParams),
    ]

    func testRoute() throws {
        let router = Router<RequestHandler>()
        router.register(path: ["0.0.0.0", Method.get.description, "hello"]) { req in
            return Response(body: "HI")
        }

        let request = try Request(method: .get, uri: "http://0.0.0.0/hello")
        let handler = router.route(request)
        XCTAssert(handler != nil)
        let response = try handler?(request).makeResponse()
        XCTAssert(response?.body.bytes?.string == "HI")
    }

    func testRouteParams() throws {
        let router = Router<RequestHandler>()
        router.register(path: ["0.0.0.0", Method.get.description, ":zero", ":one", ":two", "*"]) { req in
            let zero = req.parameters["zero"]?.string ?? "[fail]"
            let one = req.parameters["one"]?.string ?? "[fail]"
            let two = req.parameters["two"]?.string ?? "[fail]"
            return Response(body: "\(zero):\(one):\(two)")
        }

        let paths: [[String]] = [
            ["a", "b", "c"],
            ["1", "2", "3", "4"],
            ["x", "y", "z", "should", "be", "in", "wildcard"]
        ]
        try paths.forEach { path in
            let uri = URI(
                scheme: "http",
                userInfo: nil,
                host: "0.0.0.0",
                port: 80,
                path: path.joined(separator: "/"),
                query: nil,
                fragment: nil
            )
            let request = Request(method: .get, uri: uri)
            let handler = router.route(request)
            XCTAssert(handler != nil)
            let response = try handler?(request).makeResponse()
            XCTAssert(response?.body.bytes?.string == path.prefix(3).joined(separator: ":"))
        }
    }
}
