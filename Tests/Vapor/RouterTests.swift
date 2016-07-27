import Foundation
import XCTest
@testable import Vapor

class RouterTests: XCTestCase {

    static let allTests = [
       ("testSingleHostRouting", testSingleHostRouting),
       ("testMultipleHostsRouting", testMultipleHostsRouting),
       ("testURLParameterDecoding", testURLParameterDecoding)
    ]

    func testSingleHostRouting() throws {
        let router = BranchRouter()
        let compare = "Hello Text Data Processing Test"
        let data = compare.utf8

        let route = Route.init(host: "other.test", method: .get, path: "test") { request in
            return Response(status: .ok, body: data)
        }
        router.register(route)

        let request = Request(method: .get, path: "test", host: "other.test")

        guard let result = router.route(request) else {
            XCTFail("no route found")
            return
        }

        let body = try result.respond(to: request).body

        guard case .data(let bytes) = body else {
            XCTFail("Data was not buffer")
            return
        }

        let string = bytes.string
        XCTAssert(string == compare)
    }

    func testMultipleHostsRouting() throws {
        let router = BranchRouter()

        let data_1 = "1".bytes
        let data_2 = "2".bytes

        let route_1 = Route.init(method: .get, path: "test") { request in
            return Response(status: .ok, body: data_1)
        }
        router.register(route_1)

        let route_2 = Route.init(host: "vapor.test", method: .get, path: "test") { request in
            return Response(status: .ok, body: data_2)
        }
        router.register(route_2)

        let request_1 = Request(method: .get, path: "test", host: "other.test")

        let request_2 = Request(method: .get, path: "test", host: "vapor.test")

        let handler_1 = router.route(request_1)
        let handler_2 = router.route(request_2)

        if let response_1 = try? handler_1?.respond(to: request_1) {
            let body = response_1!.body
            guard case .data(let buffer) = body else {
                XCTFail("Data was not buffer")
                return
            }

            XCTAssert(buffer == data_1, "Incorrect response returned by Handler 1")
        } else {
            XCTFail("Handler 1 did not return a response")
        }

        if let response_2 = try? handler_2?.respond(to: request_2) {
            let body = response_2!.body
            guard case .data(let buffer) = body else {
                XCTFail("Data was not buffer")
                return
            }

            XCTAssert(buffer == data_2, "Incorrect response returned by Handler 2")
        } else {
            XCTFail("Handler 2 did not return a response")
        }
    }

    func testURLParameterDecoding() throws {
        let router = BranchRouter()

        let percentEncodedString = "testing%20parameter%21%23%24%26%27%28%29%2A%2B%2C%3A%3B%3D%3F%40%5B%5D"
        let decodedString = "testing parameter!#$&'()*+,:;=?@[]"

        var handlerRan = false

        let route = Route(method: .get, path: "test/:string") { request in

            let testParameter = request.parameters["string"]

            XCTAssert(testParameter == decodedString, "URL parameter was not decoded properly")

            handlerRan = true

            return Response(status: .ok, body: [])
        }
        router.register(route)

        let request = Request(method: .get, path: "test/\(percentEncodedString)")
        print("URI: \(request.uri)")
        guard let handler = router.route(request) else {
            XCTFail("Route not found")
            return
        }

        do {
            let _ = try handler.respond(to: request)
        } catch {
            XCTFail("Handler threw error \(error)")
        }

        XCTAssert(handlerRan, "The handler did not run, and the parameter test also did not run")
    }

}
