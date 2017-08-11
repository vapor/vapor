import XCTest
import Session
import HTTP
import Node

class SessionTests: XCTestCase {
    static let allTests = [
        ("testRequest", testRequest),
        ("testDestroy", testDestroy)
    ]

    func testRequest() throws {
        let s = Session(identifier: "")

        let request = Request(method: .get, uri: "http://vapor.codes")

        do {
            _ = try request.assertSession()
            XCTFail("Should have errored.")
        } catch is SessionsError {
            //
        } catch {
            XCTFail("Wrong error: \(error)")
        }

        request.session = s

        let rs = try request.assertSession()
        XCTAssert(s === rs)
    }

    func testDestroy() throws {
        let s = Session(identifier: "")
        s.data = "bar"
        s.destroy()
    }
}
