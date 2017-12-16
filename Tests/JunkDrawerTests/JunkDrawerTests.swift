import XCTest
@testable import JunkDrawer

class JunkDrawerTests: XCTestCase {
    func testFileRead() throws {
        let file = try File(queue: .global()).read(at: CommandLine.arguments[0], chunkSize: 128).blockingAwait()
        XCTAssertGreaterThan(file.count, 512)
    }
    
    static var allTests = [
        ("testFileRead", testFileRead),
    ]
}
