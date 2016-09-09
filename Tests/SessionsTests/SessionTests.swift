import XCTest
@testable import Sessions
import HTTP
import Node

class SessionTests: XCTestCase {
    static let allTests = [
        ("testRequest", testRequest),
        ("testData", testData),
        ("testDestroy", testDestroy),
        ("testError", testError),
    ]

    func testRequest() throws {
        let m = MemorySessions()
        let s = Session(sessions: m)

        let request = try Request(method: .get, uri: "http://vapor.codes")

        do {
            _ = try request.session()
            XCTFail("Should have errored.")
        } catch SessionsError.notConfigured {
            //
        } catch {
            XCTFail("Wrong error: \(error)")
        }

        request.storage["session"] = s

        let rs = try request.session()
        XCTAssert(s === rs)
    }

    func testData() throws {
        let m = MemorySessions()
        let s = Session(sessions: m)

        XCTAssertNil(s.identifier)

        s.data["foo", "bar"] = "baz"

        XCTAssert(s.identifier != nil)

        XCTAssertEqual(s.data["foo", "bar"]?.string, "baz")
    }

    func testDestroy() throws {
        let m = MemorySessions()
        let s = Session(sessions: m)

        s.data = Node("bar")

        try s.destroy()

        XCTAssertNil(s.identifier)
    }

    func testError() throws {
        let e = ErrorSessions()
        let s = Session(sessions: e)

        s.data["fetch"] = "test"
        XCTAssertNil(s.data["fetch"])
    }
}

final class ErrorSessions: SessionsProtocol {
    init() {}

    enum Error: Swift.Error {
        case test
    }

    func makeIdentifier() -> String {
        return ""
    }

    func get(for identifier: String) throws -> Node? {
        throw Error.test
    }

    func set(_ value: Node?, for identifier: String) throws {
        throw Error.test
    }
}
