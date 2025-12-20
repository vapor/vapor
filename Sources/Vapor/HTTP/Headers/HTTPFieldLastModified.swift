import Foundation
import HTTPTypes

extension HTTPFields {
    /// Represents the HTTP `Last-Modified` header.
    /// - See Also:
    /// [Last-Modified](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Last-Modified)
    public struct LastModified {
        public var value: Date

        internal static func parse(_ dateString: String) -> LastModified? {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(secondsFromGMT: 0)
            fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

            guard let date = fmt.date(from: dateString) else {
                return nil
            }

            return .init(value: date)
        }

        public func serialize() -> String {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(secondsFromGMT: 0)
            fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

            return fmt.string(from: self.value)
        }
    }

    public var lastModified: LastModified? {
        get { self[.lastModified].flatMap(LastModified.parse) }
        set {
            if let new = newValue?.serialize() {
                self[.lastModified] = new
            } else {
                self[.lastModified] = nil
            }
        }
    }
}

extension HTTPFields.LastModified {
    /// Initialize a `Last-Modified` header with a date.
    public init(_ date: Date) {
        self.init(value: date)
    }
}

