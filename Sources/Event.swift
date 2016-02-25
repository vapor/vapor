//
//  Event.swift
//  Vapor
//
//  Created by Matthew on 24/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

public class Event<T where T: AnyObject> {
    
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
    
    let tag: String
    let data: T
    
    public required init(tag: String, data: T) {
        self.tag = tag
        self.data = data
    }
}


public class Subscriber {
    
    public typealias EventHandler = (AnyObject) -> ()
    
    public static var registered: [Subscriber] = []
    
    public let tag: String
    public let priority: Int
    public let closure: EventHandler
    
    public required init(subscribesTo tag: String, priority: Int, closure: EventHandler) {
        self.tag = tag
        self.priority = priority
        self.closure = closure
    }
    
    public func handle(data: AnyObject) {
        closure(data)
    }
}
