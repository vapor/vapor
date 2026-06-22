import Foundation
import NIOHTTP1

extension HTTPHeaders {
    /// Represents the HTTP `Retry-After` header.
    ///
    /// The value is either a number of seconds to wait before retrying, or a specific
    /// date after which the client may retry. This is typically sent with `429 Too Many
    /// Requests` or `503 Service Unavailable` responses.
    /// - See Also:
    /// [Retry-After](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Retry-After)
    public enum RetryAfter {
        /// The number of seconds to wait before retrying.
        case seconds(Int)
        /// The date after which the client may retry.
        case date(Date)

        internal static func parse(_ value: String) -> RetryAfter? {
            let trimmed = value.trimmingCharacters(in: .whitespaces)

            // `delay-seconds` is a non-negative integer (RFC 9110 § 10.2.3).
            if let seconds = Int(trimmed) {
                return seconds >= 0 ? .seconds(seconds) : nil
            }

            // Otherwise the value is an HTTP-date.
            if let date = Self.parseHTTPDate(trimmed) {
                return .date(date)
            }

            return nil
        }

        public func serialize() -> String {
            switch self {
            case .seconds(let seconds):
                return String(seconds)
            case .date(let date):
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "en_US_POSIX")
                fmt.timeZone = TimeZone(secondsFromGMT: 0)
                fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                return fmt.string(from: date)
            }
        }

        private static func parseHTTPDate(_ dateString: String) -> Date? {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(secondsFromGMT: 0)

            // Preferred IMF-fixdate format (RFC 7231 § 7.1.1.1).
            fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            if let date = fmt.date(from: dateString) {
                return date
            }

            // Obsolete RFC 850 format.
            fmt.dateFormat = "EEEE, dd-MMM-yy HH:mm:ss zzz"
            if let date = fmt.date(from: dateString) {
                return date
            }

            // Obsolete ANSI C asctime() format.
            fmt.dateFormat = "EEE MMM d HH:mm:s yyyy"
            if let date = fmt.date(from: dateString) {
                return date
            }

            return nil
        }
    }

    /// Gets or sets the `Retry-After` header.
    public var retryAfter: RetryAfter? {
        get { self.first(name: .retryAfter).flatMap(RetryAfter.parse) }
        set {
            if let new = newValue?.serialize() {
                self.replaceOrAdd(name: .retryAfter, value: new)
            } else {
                self.remove(name: .retryAfter)
            }
        }
    }
}
