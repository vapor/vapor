//
//  Event.swift
//  Vapor
//
//  Created by Matthew on 24/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//



/*
 
EXAMPLE

let high = Subscriber(subscribesTo: "event.name", priority: 100) { data in
    print("High Priority - \(data)")
}

let low = Subscriber(subscribesTo: "event.name") { data in
    print("Standard Priority - \(data)")
}

let other = Subscriber(subscribesTo: "other.name") { data in
    print("Other subscriber - \(data)")
}

Subscriber.add([low, high, other])

let event = Event(tag: "event.name", data: "This is the data")
Event.fire(event)

//Prints first
"High Priority - This is the data"
//Prints second
"Standard Priority - This is the data"

 */

public struct Event<T where T: AnyObject> {
    
    //MARK: Static methods
    
    public static func fire(event: Event) {
        let subscribed = Subscriber.registered
            .filter { subscriber in
                return subscriber.tag == event.tag
            }
            .sort { $0.priority > $1.priority }
        
        subscribed.forEach { subscriber in
            subscriber.handle(event.data)
        }
    }
    
    //MARK: Properties
    
    let tag: String
    let data: T
    
    public init(tag: String, data: T) {
        self.tag = tag
        self.data = data
    }
}

public protocol Subscribable {
    func handle(data: AnyObject)
}

public typealias EventHandler = (AnyObject) -> ()

public class Subscriber: Equatable, Subscribable {
    
    //MARK: Static methods
    
    private static var registered: [Subscriber] = []
    
    public static func add(subscriber: Subscriber) {
        Subscriber.registered.append(subscriber)
    }
    
    public static func add(subscribers: [Subscriber]) {
        Subscriber.registered += subscribers
    }
    
//    
//    public static func remove(subscriber: Subscriber) {
//        guard let index = Subscriber.registered
//            .indexOf(subscriber) else { return }
//        
//        Subscriber.registered.removeAtIndex(index)
//    }
    
    //MARK: Properties
    
    public let tag: String
    public let priority: Int
    public let closure: EventHandler
    
    public required init(subscribesTo tag: String, priority: Int = 50, closure: EventHandler) {
        self.tag = tag
        self.priority = priority
        self.closure = closure
    }
    
    public func handle(data: AnyObject) {
        closure(data)
    }
}

public func ==(lhs: Subscriber, rhs: Subscriber) -> Bool {
    return String(lhs) == String(rhs)
}

