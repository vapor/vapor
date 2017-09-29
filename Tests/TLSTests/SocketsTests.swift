import TLS
import XCTest

class SocketsTests: XCTestCase {
    func testInit() throws {
        let socket = Socket()
        print(socket)
    }

    static let allTests = [
        ("testInit", testInit)
    ]
}
