import Foundation
import Vapor
import XCTest


class RoutingTests : XCTestCase {
    
    func testGroupContainsRoute() {
        let router = MockRouter()
        let sut = router.group("test")
        XCTAssertTrue(sut.components.contains(where: { $0 == "test"}))
    }
    
    // FIXME: We need more testable router
}


