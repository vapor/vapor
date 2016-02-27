//
//  Event.swift
//  Vapor
//
//  Created by Matthew on 27/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//


//MARK: Subscriber

public typealias Continue = Bool
public typealias EventHandler = (Any) -> (Continue)

//Required until static vars can be stored in generic classes
public class SubscriberContainer {
    public static var subscribers: [Subscriber] = []
}

/*a
   Subscriber Protocol. All event subscribers must confirm to this
   protocol.
 */
public protocol Subscriber {
    
    /**
        The event type. Must conform to the `EventType` protocol.
        By convention, this is an enum.
     */
     var type: EventType { get }
    
    /**
        Int that determines the order in which the event
        is passed to the subscriber.
     */
    var priority: Int { get }
    
    /**
        This method process the event data. This must return `true` 
        to continue propagation. Returning `false` cancels
        all subsequent subscribers.
     
        - returns bool
     */
    func handle(data: Any) -> Continue
    
}

//MARK: Event

/**
   Event types are used to identify which Subscribers
   should respond to an Event. They must conform to `EventType`
   protocol. By convention, this is an enum.

 */
public protocol EventType {
    var rawValue: String { get }
}

extension EventType {
    internal var identifier: String { return String(ObjectIdentifier(Self).hashValue) + rawValue }
}

/**
    Events contain the data that is passed to Subscribers
    that are registered to listen to the given Event.
 */
public class Event<T, U where T: EventType, U: Any> {
    
    /**
        Fires an Event. Event progagation is cancelled when
        a subscriber `handle` method returns `false`.
     
        - parameter event: The Event object
     
     */
    public static func fire(event: Event) {
        
        let subscribed = SubscriberContainer.subscribers
            .filter { subscriber in
                subscriber.type.identifier == event.type.identifier
            }
            .sort { $0.priority > $1.priority }
        
        for subscriber in subscribed {
            if false == subscriber.handle(event.data) {
                break
            }
        }
    }
    
    /**
        The event type. Must conform to the `EventType` protocol.
        By convention, this is an enum.
     */
    let type: T
    
    /**
        The data that is passed to Subscribers. Can be of
        type `Any`.
     */
    let data: U
    
    /**
        Initializer
     
        - parameter type: The EventType used to identify the event
        - parameter: data: Any - the data passed to subscribers
            to process
     */
    public required init(_ type: T, data: U) {
        self.type = type
        self.data = data
    }
}
