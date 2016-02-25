//
//  Event.swift
//  Vapor
//
//  Created by Matthew on 24/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

/*
 Enums used to identify events must implement this protocol
 */
public protocol EventType {
    var rawValue: String { get }
}

extension EventType {
    var identifier: String { return String(self) + self.rawValue}
}

/*
 Event class
 */
public class Event<T, U where T: EventType, U: Any> {
    
    /* Fires the event and passes the event to each subscriber registered for the specific event
     
     - parameter event: The Event object
     */
    public static func fire(event: Event) {
        let subscribed = Subscriber.registered
            .filter { subscriber in
                return subscriber.type.identifier == event.type.identifier
            }
            .sort { $0.priority > $1.priority }
        
        for subscriber in subscribed {
            if !subscriber.handle(event.data) {
                break
            }
        }
    }
    
    let type: T
    let data: U
    
    /* Initializer
     
     - parameter type: The EventType used to identify susbcribers that should respond to this event
     - parameter: data: Any - the data passed to subscribers to respond to
     */
    public required init(_ type: T, data: U) {
        self.type = type
        self.data = data
    }
}

//MARK: Subscriber

public typealias Continue = Bool
public typealias EventHandler = (Any) -> (Continue)

/*
 Subcribers must implement this protocol
 */
public protocol Subscribable {
    func handle(data: Any) -> Continue
    var priority: Int { get }
    var type: EventType { get }
}

/* Subscriber class - listens to events that are fired.
 */
public class Subscriber: Subscribable {
    
    /*
     Array of subscribers that are registerd in the application
     */
    private(set) static var registered: [Subscribable] = []
    
    /*
     Registers a single subscriber
     
     - parameter subscriber: A subscriber
     */
    public static func add(subscriber: Subscribable) {
        Subscriber.registered.append(subscriber)
    }
    
    /*
     Registers an array of subscribers
     
    - parameter subs: An array of subscribers
     */
    public static func add(subs: [Subscribable]) {
        Subscriber.registered += subs
    }
    
    //MARK: Properties
    
    public let type: EventType
    public let priority: Int
    public let closure: EventHandler
    
    /*
     Initializer
     
     - parameter type: The event type the subscriber should respond to
     - parameter priority: Int that determines the order in which the event 
          is passed to the subscriber
     - closure: A closure that receives the event data object
     */
    public required init(_ type: EventType, priority: Int = 50, closure: EventHandler) {
        self.type = type
        self.priority = priority
        self.closure = closure
    }
    
    /*
     This calls the closure
    */
    public func handle(data: Any) -> Continue {
        return closure(data)
    }
}
