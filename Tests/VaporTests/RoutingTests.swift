import Foundation
import Vapor
import XCTest


class RoutingTests : XCTestCase {
    func testGroup() {
        let router = MockRouter()
        let sut = router.grouped("test")
        XCTAssertNotNil(sut) // test that there is no error
    }
    
    func testGroupConfigure() {
        let sut = MockRouter()
        let exp = expectation(description: "Router Group configuration called")
        sut.group("") { group in
            group.get("") { _ in
                return "test"
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testUsingMiddlewareAsFunction() {
        let router = MockRouter()
        let sut = router.grouped { req, next in
            return try next.respond(to: req)
        }
        XCTAssertNotNil(sut) // test that there is no error
    }
    
    func testUsingMiddleware() {
        let router = MockRouter()
        let sut = router.grouped(FakeMiddleware())
        XCTAssertNotNil(sut) // test that there is no error
    }
    
    func testUsingMiddlewareAsFunctionWithConfiguration() {
        let router = MockRouter()
        let exp = expectation(description: "Router Group configuration called")
        router.group({ req, next in
            return try next.respond(to: req)
        }) { group in
            group.get("") { _ in
                return "test"
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testUsingMiddlewareWithConfiguration() {
        let router = MockRouter()
        let exp = expectation(description: "Router Group configuration called")
        
        router.group(FakeMiddleware()) { group in
            group.get("") { _ in
                return "test"
            }
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    // FIXME: We need more testable router
}


