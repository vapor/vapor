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
        let response = try Response.withETag(DTO(), justCreated: true)
        try validate(response, status: .created)
    }

    func testExisting() throws {
        let response = try Response.withETag(DTO())
        try validate(response, status: .ok)
    }

    func testNoBody() throws {
        let response = try Response.withETag(DTO(), includeBody: false)
        try validate(response, status: .noContent, nilBody: true)
    }

    func testEtagFromContent() throws {
        let eTag = try XCTUnwrap(DTO().eTag())
        XCTAssertNotNil(eTag.range(of: Self.regex, options: .regularExpression))
    }

    func testIfNoneMatchHeaderMatches() throws {
        let dto = DTO()
        let eTag = try XCTUnwrap(dto.eTag())

        var headers = HTTPHeaders()
        headers.add(name: .ifNoneMatch, value: eTag)

        let app = Application(.testing)
        defer { app.shutdown() }

        let request = Request(application: app, headers: headers, on: app.eventLoopGroup.next())
        let response = try Response.withETag(dto, req: request)
        XCTAssertEqual(response.status, .notModified)
    }

    func testIfNoneMatchDoesNotMatch() throws {
        var headers = HTTPHeaders()
        headers.add(name: .ifNoneMatch, value: UUID().uuidString)

        let app = Application(.testing)
        defer { app.shutdown() }

        let request = Request(application: app, headers: headers, on: app.eventLoopGroup.next())
        let response = try Response.withETag(DTO(), req: request)
        XCTAssertEqual(response.status, .ok)
    }

    func testIfNonMatchWithList() throws {
        let dto = DTO()
        let eTag = try XCTUnwrap(dto.eTag())

        var headers = HTTPHeaders()
        headers.add(name: .ifNoneMatch, value: "abc, \(eTag), def")

        let app = Application(.testing)
        defer { app.shutdown() }

        let request = Request(application: app, headers: headers, on: app.eventLoopGroup.next())

        let response = try Response.withETag(dto, req: request)
        XCTAssertEqual(response.status, .notModified)
    }
}


private struct DTO: Content {
    let data = UUID().uuidString
}
