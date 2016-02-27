//
//  EventTests.swift
//  Vapor
//
//  Created by Matthew on 27/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor
//
//#if os(Linux)
//    extension RouteTests: XCTestCaseProvider {
//        var allTests : [(String, () throws -> Void)] {
//            return [
//                       ("testRoute", testRoute),
//                       ("testRouteScopedPrefix", testRouteScopedPrefix)
//            ]
//        }
//    }
//#endif

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
            return true
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

    
    func prepare() {
        
        //Reset all of the data
        
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
    
    func testSubscribersDidLoadInApplication() {
        prepare()
        
        SubscriberContainer.subscribers = []
        
        let app = Application()
        app.subscribers = subscribers
        app.start()
        
        XCTAssertEqual(4, SubscriberContainer.subscribers.count, "4 subscribers should load")
        
    }
    
    
    func testSubscribersDidRespondToEventCorrectly() {
        prepare()
        
        let event = Event(TestEvents.FooEvent, data: "dummy")
        Event.fire(event)
        
        XCTAssertEqual(2, EventTests.responded.count, "2 subscribers should have responded to .FooEvent")
        
    }

    
//    func testRoute() {
//        
//    
////        let event = Event(type: SystemEvents.ApplicationDidStart, data: "This is the data")
//
//        
//        class HighSubscriber: Subscriber {
//        
//            let type: EventType = SystemEvents.UserRegistered
//            let priority: Int = 100
//        
//            func handle(data: Any) -> Continue {
//                print("I did something with the user")
//                return true
//            }
//        }
//        
//        public class LowSubscriber: Subscriber {
//        
//            public let type: EventType = SystemEvents.UserRegistered
//            public let priority: Int = 0
//        
//            public func handle(data: Any) -> Continue {
//                print("I did something with the user")
//                return true
//            }
//        }
//        
//        struct User {
//            let name: String
//        }
//        
//        enum SystemEvents: String, EventType {
//            case ApplicationDidStart, UserRegistered
//        }
//        
//        enum MyEvents: String, EventType {
//            case CustomEvent
//        }
//        
//        let user = User(name: "John Doe")
//        
//        
//        
//        let event = Event(SystemEvents.UserRegistered, data: user)
//        Event.fire(event)
//        
//        
//
//        
//        
//    }

}