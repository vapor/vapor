//
//  LogLevel.swift
//  Vapor
//
//  Created by Matthew on 22/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

/*
 LogLevel enumeration
 */
public enum LogLevel {
    case Verbose, Debug, Info, Warning, Error, Fatal, Custom(String)
    
    /*
     Returns all standard log levels (i.e. except Custom)
    
     returns - array of LogLevel
     */
    public static var all: [LogLevel] {
        return [.Verbose, .Debug, .Info, .Warning, .Error, .Fatal]
    }
}

//MARK: Protocol conformance

extension LogLevel: CustomStringConvertible {
    public var description: String {
        switch self {
        case Verbose: return "VERBOSE"
        case Debug: return "DEBUG"
        case Info: return "INFO"
        case Warning: return "WARNING"
        case Error: return "ERROR"
        case Fatal: return "FATAL"
        case Custom(let string): return "\(string.uppercaseString)"
        }
    }
}

extension LogLevel: Equatable {}

public func ==(lhs: LogLevel, rhs: LogLevel) -> Bool {
    return lhs.description == rhs.description
}

