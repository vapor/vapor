import XCTest
@testable import Sessions
import HTTP
import Node

class SessionTests: XCTestCase {
    static let allTests = [
        ("testRequest", testRequest),
        ("testDestroy", testDestroy)
    ]

    func testRequest() throws {
        let s = Session(identifier: "")

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

    func testDestroy() throws {
        let s = Session(identifier: "")

        s.data = Node("bar")

        s.destroy()

        XCTAssertTrue(s.shouldDestroy)
    }
}
