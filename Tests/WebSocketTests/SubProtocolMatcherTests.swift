@testable import WebSocket
import XCTest

final class SubProtocolMatcherTests : XCTestCase {
    static let allTests = [
        ("testEmptyRequestAndEmptyRouterShouldReturnNil", testEmptyRequestAndEmptyRouterShouldReturnNil),

        ("testEmptyStringsRequestAndEmptyRouterShouldReturnNil", testEmptyStringsRequestAndEmptyRouterShouldReturnNil),

        ("testRequestAndRouterHaveTheSameSubProtocolsInSameOrderShouldReturnTheFirst", testRequestAndRouterHaveTheSameSubProtocolsInSameOrderShouldReturnTheFirst),

        ("testRequestAndRouterHaveTheSameSubProtocolsInDifferentOrderShouldReturnTheFirstDeclaredByRouter", testRequestAndRouterHaveTheSameSubProtocolsInDifferentOrderShouldReturnTheFirstDeclaredByRouter),

        ("testRouterHasOneSubProtocolOfTheRequestShouldReturnTheOnlyDeclaredByRouter", testRouterHasOneSubProtocolOfTheRequestShouldReturnTheOnlyDeclaredByRouter),

        ("testRequestHasOneSubProtocolOfTheRouterShouldReturnTheOnlyDeclaredByRequest", testRequestHasOneSubProtocolOfTheRouterShouldReturnTheOnlyDeclaredByRequest),

        ("testThrowsErrorWhenRouterDeclaresNoSubProtocolButRequestDeclaresAny", testThrowsErrorWhenRouterDeclaresNoSubProtocolButRequestDeclaresAny),

        ("testThrowsErrorWhenRequestDeclaresNoSubProtocolButRouterDeclaresAny", testThrowsErrorWhenRequestDeclaresNoSubProtocolButRouterDeclaresAny),

        ("testIfSearchForTheMatchingSubProtocolIsOptimal", testIfSearchForTheMatchingSubProtocolIsOptimal)
    ]

    func testEmptyRequestAndEmptyRouterShouldReturnNil() throws {
        let response = try SubProtocolMatcher(request: [], router: []).matching()
        XCTAssertNil(response, "When neither request nor router declare subprotocol, the matching subprotocol (response) should be nil.")
    }

    func testEmptyStringsRequestAndEmptyRouterShouldReturnNil() throws {
        let response = try SubProtocolMatcher(request: [""], router: [""]).matching()
        XCTAssertNil(response, "When neither request nor router declare subprotocol, the matching subprotocol (response) should be nil.")
    }

    func testRequestAndRouterHaveTheSameSubProtocolsInSameOrderShouldReturnTheFirst() throws {
        let response = try SubProtocolMatcher(request: ["aprotocol", "anotherprotocol"],
                                              router: ["aprotocol", "anotherprotocol"]).matching()
        XCTAssertEqual(response, "aprotocol", "When both request and router declare the same subprotocols in the same order, the matching subprotocol (response) should be the first.")
    }

    func testRequestAndRouterHaveTheSameSubProtocolsInDifferentOrderShouldReturnTheFirstDeclaredByRouter() throws {
        let response = try SubProtocolMatcher(request: ["aprotocol", "anotherprotocol"],
                                              router: ["anotherprotocol", "aprotocol"]).matching()
        XCTAssertEqual(response, "anotherprotocol", "When both request and router declare the same subprotocols in the different order, the matching subprotocol (response) should be the first declared by router.")
    }

    func testRouterHasOneSubProtocolOfTheRequestShouldReturnTheOnlyDeclaredByRouter() throws {
        let response = try SubProtocolMatcher(request: ["aprotocol", "anotherprotocol"],
                                              router: ["anotherprotocol"]).matching()
        XCTAssertEqual(response, "anotherprotocol", "When router declares one of the subprotocols declared by the request, the matching subprotocol (response) should be the only declared by the router.")
    }

    func testRequestHasOneSubProtocolOfTheRouterShouldReturnTheOnlyDeclaredByRequest() throws {
        let response = try SubProtocolMatcher(request: ["aprotocol"],
                                              router: ["aprotocol", "anotherprotocol"]).matching()
        XCTAssertEqual(response, "aprotocol", "When request declares one of the subprotocols declared by the router, the matching subprotocol (response) should be the only declared by the request.")
    }

    func testThrowsErrorWhenRouterDeclaresNoSubProtocolButRequestDeclaresAny() throws {
        let matcher = SubProtocolMatcher(request: ["aprotocol"], router: [])

        XCTAssertThrowsError(try matcher.matching(), "When the router declares no subprotocols and the request declares any, an WebSocketError(.invalidSubprotocol) should be thrown.")
    }

    func testThrowsErrorWhenRequestDeclaresNoSubProtocolButRouterDeclaresAny() throws {
        let matcher = SubProtocolMatcher(request: [], router: ["aprotocol"])

        XCTAssertThrowsError(try matcher.matching(), "When the request declares no subprotocols and the router declares any, an WebSocketError(.invalidSubprotocol) should be thrown.")
    }

    func testIfSearchForTheMatchingSubProtocolIsOptimal() throws {
        // uncomment to test performance
        /*
        var tonsOfProtocols = [String]()

        let lastIndex = 1_000_000
        for index in 0...(lastIndex + 1) {
            tonsOfProtocols.append("subprotocol-\(index)")
        }

        let matcher = SubProtocolMatcher(request: [tonsOfProtocols[lastIndex]], router: tonsOfProtocols)

        self.measure {
            _ = try? matcher.matching()
        }
        */
    }
}

