import Foundation
import NIO

fileprivate final class ISO8601 {
    fileprivate static let threadSpecific: ThreadSpecificVariable<ISO8601DateFormatter> = .init()
}

extension ISO8601DateFormatter {
    static var threadSpecific: ISO8601DateFormatter {
        if let existing = ISO8601.threadSpecific.currentValue {
            return existing
        } else {
            let new = ISO8601DateFormatter()
            ISO8601.threadSpecific.currentValue = new
            return new
        }
    }
}
