//
//  EventTests.swift
//  Vapor
//
//  Created by Matthew on 27/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

#if os(Linux)
    extension EventTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                       ("testSubscribersDidLoadInApplication", testSubscribersDidLoadInApplication),
                       ("testSubscribersDidRespondToEvent", testSubscribersDidRespondToEvent),
                       ("testSubscribersDidFireInOrderOfPriority", testSubscribersDidFireInOrderOfPriority),
                       ("testSubscribersReturningFalseStopsPropogation", testSubscribersReturningFalseStopsPropogation),
                       
            ]
        }
    }
#endif

class EventTests: XCTestCase {

    var subscribers: [Subscriber] = []
    static var responded: [Subscriber] = []
    
    //MARK: Set up
    
    private enum TestEvents: String, EventType {
        case FooEvent, BarEvent
    }
    
    private class HighFooSubscriber: Subscriber {
        let type: EventType = TestEvents.FooEvent
        let priority: Int = 100
        
        func handle(data: Any) -> Continue {
            EventTests.responded.append(self)
            return true
        }
    }
    
    private class LowFooSubscriber: Subscriber {
        let type: EventType = TestEvents.FooEvent
        let priority: Int = 50
        
        func handle(data: Any) -> Continue {
            EventTests.responded.append(self)
            return true
        }
    }
    
    private class BarFalseSubscriber: Subscriber {
        let type: EventType = TestEvents.BarEvent
        let priority: Int = 100
        
        func handle(data: Any) -> Continue {
            EventTests.responded.append(self)
            return false
        }
    }
    
    private class BarTrueSubscriber: Subscriber {
        let type: EventType = TestEvents.BarEvent
        let priority: Int = 50
        
        func handle(data: Any) -> Continue {
            EventTests.responded.append(self)
            return true
        }
    }

    //Set up the test dependencies
    func prepare() {
        EventTests.responded = []
        
        subscribers = [
          LowFooSubscriber(),
          HighFooSubscriber(),
          BarTrueSubscriber(),
          BarFalseSubscriber()
        ]
        
        SubscriberContainer.subscribers = subscribers
    }
    
    //MARK: Tests
    private func fire(type: TestEvents = .FooEvent) {
        let event = Event(type, data: "dummy")
        Event.fire(event)
    }
    
    func testSubscribersDidLoadInApplication() {
        prepare()
        SubscriberContainer.subscribers = []
        
        let app = Application()
        app.subscribers = subscribers
        app.start()
        
        XCTAssertEqual(4, SubscriberContainer.subscribers.count, "4 subscribers should load")
    }
    
    func testSubscribersDidRespondToEvent() {
        prepare()
        fire()
        XCTAssertEqual(2, EventTests.responded.count, "2 subscribers should have responded to FooEvent")
    }
    
    func testSubscribersDidFireInOrderOfPriority() {
        prepare()
        fire()
        XCTAssertTrue(String(EventTests.responded[0]).containsString("HighFooSubscriber"), "HighFooSubscriber should respond before LowFooSubscriber")
    }
    
    func testSubscribersReturningFalseStopsPropogation() {
        prepare()
        fire(.BarEvent)
        XCTAssertEqual(1, EventTests.responded.count, "only 1 bar subscriber should respond")
    }

}