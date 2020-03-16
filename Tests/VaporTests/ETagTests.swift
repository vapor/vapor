import Vapor
import XCTest

final class ETagTests: XCTestCase {
    static let regex = "^\"[a-fA-F0-9]+\"$"

    private func validate(_ response: Response, status: HTTPStatus, nilBody: Bool = false, line: UInt = #line) throws {
        let eTag = try XCTUnwrap(response.headers.firstValue(name: .eTag))
        XCTAssertNotNil(eTag.range(of: Self.regex, options: .regularExpression), line: line)

        XCTAssertEqual(response.status, status, line: line)

        if nilBody {
            XCTAssertNil(response.body.string, "Found a body", line: line)
        } else {
            XCTAssertNotNil(response.body.string, "Didn't find a body", line: line)
        }
    }

    func testNewlyCreated() throws {
        let response = try Response.withETag(obj: DTO(), justCreated: true)
        try validate(response, status: .created)
    }

    func testExisting() throws {
        let response = try Response.withETag(obj: DTO())
        try validate(response, status: .ok)
    }

    func testNoBody() throws {
        let response = try Response.withETag(obj: DTO(), includeBody: false)
        try validate(response, status: .noContent, nilBody: true)
    }

    func testEtagFromContent() throws {
        let content = DTO()
        let eTag = try XCTUnwrap(content.eTag())
        XCTAssertNotNil(eTag.range(of: Self.regex, options: .regularExpression))
    }
}


private struct DTO: Content {
    let data = "something"
}
