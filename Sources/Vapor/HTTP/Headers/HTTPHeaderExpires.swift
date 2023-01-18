import NIO

extension HTTPHeaders {
    public struct Expires {
        /// The date represented by the header.
        public let expires: Date

        internal static func parse(_ dateString: String) -> Expires? {
            // https://tools.ietf.org/html/rfc7231#section-7.1.1.1
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(secondsFromGMT: 0)
            fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

            if let date = fmt.date(from: dateString) {
                return .init(expires: date)
            }

            // Obsolete RFC 850 format
            fmt.dateFormat = "EEEE, dd-MMM-yy HH:mm:ss zzz"
            if let date = fmt.date(from: dateString) {
                return .init(expires: date)
            }

            // Obsolete ANSI C asctime() format
            fmt.dateFormat = "EEE MMM d HH:mm:s yyyy"
            if let date = fmt.date(from: dateString) {
                return .init(expires: date)
            }

            return nil
        }

        init(expires: Date) {
            self.expires = expires
        }

        /// Generates the header string for this instance.
        public func serialize() -> String {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(secondsFromGMT: 0)
            fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

            return fmt.string(from: expires)
        }
    }

    /// Gets the value of the `Expires` header, if present.
    /// ### Note ###
    /// `Expires` is legacy and you should switch to using `CacheControl` if possible.
    public var expires: Expires? {
        get { self.first(name: .expires).flatMap(Expires.parse) }
        set {
            if let new = newValue?.serialize() {
                self.replaceOrAdd(name: .expires, value: new)
            } else {
                self.remove(name: .expires)
            }
        }
    }
}
