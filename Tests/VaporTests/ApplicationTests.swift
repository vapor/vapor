import Async
import Bits
import Dispatch
import HTTP
import Routing
import Vapor
import TCP
import XCTest

class ApplicationTests: XCTestCase {
    func testAnyResponse() throws {
        let response = "hello"
        let app = try Application()
        var result = Response(using: app)
        let req = Request(using: app)
        
        AnyResponse(response).map { encodable in
            try encodable.encode(to: &result, for: req).blockingAwait()
            XCTAssertEqual(result.http.body.data, Data("hello".utf8))
        }.catch { error in
            XCTFail("\(error)")
        }
        
        let response2: Future<String?> = Future(nil)
        let response3: Future<String?> = Future("test")
        
        AnyResponse(future: response2, or: "fail").map { encodable in
            try encodable.encode(to: &result, for: req).blockingAwait()
            XCTAssertEqual(result.http.body.data, Data("fail".utf8))
        }.catch { error in
            XCTFail("\(error)")
        }
        
        AnyResponse(future: response3, or: "fail").map { encodable in
            try encodable.encode(to: &result, for: req).blockingAwait()
            XCTAssertEqual(result.http.body.data, Data("test".utf8))
        }.catch { error in
            XCTFail("\(error)")
        }
    }

    static let allTests = [
        ("testAnyResponse", testAnyResponse),
    ]
}
