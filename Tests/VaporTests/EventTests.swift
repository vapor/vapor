import XCTest
@testable import Vapor

class EventTests: XCTestCase {
    static let allTests = [
        ("testEventRemovedOnSubscriptionDeallocation", testEventRemovedOnSubscriptionDeallocation),
        ("testInputAndEventRun", testInputAndEventRun)
    ]

    func testEventRemovedOnSubscriptionDeallocation() {
        let emptyEvent = Event<Void>()
        let _ = emptyEvent.subscribe {
            XCTFail("Event shouldn't receive posts if 'subscription' isn't retained")
        }
        emptyEvent.post()
    }

    func testInputAndEventRun() {
        let stringEvent = Event<String>()
        var ran = false
        var subscriber: Subscription? = stringEvent.subscribe { input in
            ran = true
            XCTAssert(input == "input", "Event passed incorrect data")
        }
        stringEvent.post("input")
        subscriber = nil
        XCTAssert(ran == true, "subscription didn't run")
        let msg = "subscriber must be nil -- silences 'variable not read' warning"
        XCTAssertNil(subscriber, msg)
    }
}
