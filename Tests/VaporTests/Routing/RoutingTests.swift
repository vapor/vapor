import Foundation
import Vapor
import XCTest


class RoutingTests : XCTestCase {
    
    func testGroup() {
        let router = MockRouter()
        let sut = router.group("test")
        XCTAssertNotNil(sut) // test that there is no error
    }
    
    func testGroupConfigure() {
        let sut = MockRouter()
        let exp = expectation(description: "Router Group configuration called")
        sut.grouped(with: "") { group in
            group.get("") { _ in
                return Future("test")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    
    func testUsingMiddlewareAsFunction() {
        let router = MockRouter()
        let sut = router.using({ req, next in
            return try next.respond(to: req)
        })
        XCTAssertNotNil(sut) // test that there is no error
    }
    
    func testUsingMiddleware() {
        let router = MockRouter()
        let sut = router.using(FakeMiddleware())
        XCTAssertNotNil(sut) // test that there is no error
    }
    
    func testUsingMiddlewareAsFunctionWithConfiguration() {
        let router = MockRouter()
        let exp = expectation(description: "Router Group configuration called")
        let midfunc: MiddlewareFunction.Respond = { req, next in
            return try next.respond(to: req)
        }
        router.use(midfunc) { group in
            group.get("") { _ in
                return Future("test")
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1)
    }
    
    func testUsingMiddlewareWithConfiguration() {
        let router = MockRouter()
        let exp = expectation(description: "Router Group configuration called")
        
        router.using(FakeMiddleware()) { group in
            group.get("") { _ in
                return Future("test")
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1)
    }
    
    // FIXME: We need more testable router
}


