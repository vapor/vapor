//
//  SessionDriver.swift
//  Vapor
//
//  Created by James Richard on 2/28/16.
//

/**
 A `SessionDriver` defines the interface used to create, manage, and access
 `Session` objects.
 */
public protocol SessionDriver {
    /**
     Vapor will use the subscript operator to ask for a session based
     on an identifier. If no session exists, one must be created.
     
     - parameter    sessionIdentifier:  The `String` used to identify a `Session`
     - returns:     A session identifiable by the sessionIdentifier.
     */
    subscript(sessionIdentifier: String) -> Session { get }
}
