import Async
import Bits
import HTTP
import Routing
import Vapor
import TCP
import XCTest

class ApplicationTests: XCTestCase {
    func testCORSMiddleware() throws {
        let app = Application()
        let cors = CORSMiddleware()
        
        let router = try app.make(SyncRouter.self).grouped(cors) as SyncRouter
        
        router.post("good") { req in
            return try Response(
                status: .ok,
                body: "hello"
            )
        }
        
        var request = Request(
            method: .options,
            uri: "/good",
            headers: [
                .origin: "http://localhost:8090",
                .accessControlRequestHeaders: "POST",
            ]
        )
        
        var response = try router.route(request: request)?.respond(to: request).blockingAwait()
        
        XCTAssertEqual(response?.status, 200)
        XCTAssertNotEqual(response?.body.data, Data("hello".utf8))
        
        request = Request(method: .get, uri: "/good")
        response = try router.route(request: request)?.respond(to: request).blockingAwait()
        
        XCTAssertNotEqual(response?.status, 200)
        XCTAssertNotEqual(response?.body.data, Data("hello".utf8))
        
        request = Request(method: .post, uri: "/good")
        response = try router.route(request: request)?.respond(to: request).blockingAwait()
        
        XCTAssertEqual(response?.status, 200)
        XCTAssertEqual(response?.body.data, Data("hello".utf8))
    }
}
