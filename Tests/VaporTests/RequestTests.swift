import Vapor
import XCTest

class RequestTests: XCTestCase {
    func testQueryGet() throws {
        var req: Request
        
        //
        req = Request(method: .GET, url: .init(string: "/path?foo=a"), on: EmbeddedChannel())

        XCTAssertEqual(try req.query.get(String.self, at: "foo"), "a")
        XCTAssertThrowsError(try req.query.get(Int.self, at: "foo")) { error in
            if case .typeMismatch(_, let context) = error as? DecodingError {
                XCTAssertEqual(context.debugDescription, "Data found at 'foo' was not Int")
            } else {
                XCTFail("Catched error \"\(error)\", but not the expected: \"DecodingError.typeMismatch\"")
            }
        }
        XCTAssertThrowsError(try req.query.get(String.self, at: "bar")) { error in
            if case .valueNotFound(_, let context) = error as? DecodingError {
                XCTAssertEqual(context.debugDescription, "No String was found at 'bar'")
            } else {
                XCTFail("Catched error \"\(error)\", but not the expected: \"DecodingError.valueNotFound\"")
            }
        }

        XCTAssertEqual(req.query[String.self, at: "foo"], "a")
        XCTAssertEqual(req.query[String.self, at: "bar"], nil)
        
        //
        req = Request(method: .GET, url: .init(string: "/path"), on: EmbeddedChannel())
        XCTAssertThrowsError(try req.query.get(Int.self, at: "foo")) { error in
            if let error = error as? Abort {
                XCTAssertEqual(error.status, .unsupportedMediaType)
            } else {
                XCTFail("Catched error \"\(error)\", but not the expected: \"\(Abort(.unsupportedMediaType))\"")
            }
        }
        XCTAssertEqual(req.query[String.self, at: "foo"], nil)
    }
}
