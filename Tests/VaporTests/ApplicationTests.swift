import Async
import Bits
import Dispatch
import HTTP
import Routing
import Vapor
import TCP
import XCTest

class ApplicationTests: XCTestCase {
    func testCORSMiddleware() throws {
        let app = try Application()
        let cors = CORSMiddleware()
        
        let router = try app.make(Router.self).grouped(cors)
        
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
                .accessControlRequestMethod: "POST",
            ],
            worker: EventLoop.default
        )
        
        let trieRouter = try app.make(TrieRouter.self)
        
        if let responder = trieRouter.fallbackResponder {
            trieRouter.fallbackResponder = cors.makeResponder(chainedTo: responder)
        }
        
        var response = try router.route(request: request)?.respond(to: request).blockingAwait()
        
        try response?.body.withUnsafeBytes { pointer in
            let data = Array(ByteBuffer(start: pointer, count: response!.body.count ?? 0))
            XCTAssertNotEqual(data, Array("hello".utf8))
        }
        
        request = Request(method: .get, uri: "/good", worker: EventLoop.default)
        response = try router.route(request: request)?.respond(to: request).blockingAwait()
        
        XCTAssertNotEqual(response?.status, 200)
        try response?.body.withUnsafeBytes { pointer in
            let data = Data(ByteBuffer(start: pointer, count: response!.body.count ?? 0))
            XCTAssertNotEqual(data, Data("hello".utf8))
        }
        
        request = Request(method: .post, uri: "/good", worker: EventLoop.default)
        response = try router.route(request: request)?.respond(to: request).blockingAwait()
        
        XCTAssertEqual(response?.status, 200)
        try response?.body.withUnsafeBytes { pointer in
            let data = Data(ByteBuffer(start: pointer, count: response!.body.count ?? 0))
            XCTAssertEqual(data, Data("hello".utf8))
        }
    }
    
    func testAnyResponse() throws {
        let response = "hello"
        var result = Response()
        let req = Request(worker: EventLoop.default)
        EventLoop.default.container = try Application()
        
        AnyResponse(response).map { encodable in
            try encodable.encode(to: &result, for: req).blockingAwait()
            XCTAssertEqual(result.body.data, Data("hello".utf8))
        }.catch { error in
            XCTFail("\(error)")
        }
        
        let response2: Future<String?> = Future(nil)
        let response3: Future<String?> = Future("test")
        
        AnyResponse(future: response2, or: "fail").map { encodable in
            try encodable.encode(to: &result, for: req).blockingAwait()
            XCTAssertEqual(result.body.data, Data("fail".utf8))
        }.catch { error in
            XCTFail("\(error)")
        }
        
        AnyResponse(future: response3, or: "fail").map { encodable in
            try encodable.encode(to: &result, for: req).blockingAwait()
            XCTAssertEqual(result.body.data, Data("test".utf8))
        }.catch { error in
            XCTFail("\(error)")
        }
    }

    static let allTests = [
        ("testCORSMiddleware", testCORSMiddleware),
    ]
}
