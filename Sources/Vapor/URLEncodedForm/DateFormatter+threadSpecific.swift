//
//  File.swift
//  
//
//  Created by Ravneet Singh on 3/29/20.
//

import NIO

fileprivate final class ISO8601 {
    fileprivate static let thread: ThreadSpecificVariable<ISO8601DateFormatter> = .init()
}

extension ISO8601DateFormatter {
    static var threadSpecific: ISO8601DateFormatter {
        if let existing = ISO8601.thread.currentValue {
            return existing
        } else {
            let new = ISO8601DateFormatter()
            ISO8601.thread.currentValue = new
            return new
        }
    }
}

/// Should return a `DateFormatter` that is thread specific
public protocol ThreadSpecificDateFormatter {
    /// Returns a thread specific `DateFormatter`
    var currentValue: DateFormatter { get }
}
