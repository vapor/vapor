//
//  Log.swift
//  Vapor
//
//  Created by Matthew on 21/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

public enum LogLevel: String {
    case Verbose, Debug, Info, Warning, Error, Fatal
}

extension LogLevel: CustomStringConvertible {
    public var description: String { return self.rawValue }
}

public protocol Loggable: CustomStringConvertible {
    var date: NSDate { get }
    var level: LogLevel { get }
    var message: String { get }
}

extension Loggable {
    public var description: String {
        return "[\(date)] \(level): \(message)"
    }
}

public struct Log: Loggable {
    public let level: LogLevel
    public let date: NSDate = NSDate()
    public let message: String
    
    public init(level: LogLevel, message: String) {
        self.level = level
        self.message = message
    }
}

