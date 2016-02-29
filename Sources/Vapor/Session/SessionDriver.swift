//
//  SessionDriver.swift
//  Vapor
//
//  Created by James Richard on 2/28/16.
//

/**
 A `SessionDriver` defines the interface used to manage, and access
 session data.
 */
public protocol SessionDriver {
    func valueForKey(key: String, inSessionIdentifiedBy sessionIdentifier: String) -> String?
    func setValue(value: String?, forKey key: String, inSessionIdentifiedBy sessionIdentifier: String)
}
