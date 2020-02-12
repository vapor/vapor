import NIO

public struct HTTPHeaderExpires {
    /// The date represented by the header.
    public let expires: Date

    init?(dateString: String) {
        // https://tools.ietf.org/html/rfc7231#section-7.1.1.1
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "EEE, dd MMM yyyy hh:mm:ss zzz"
        
        if let date = fmt.date(from: dateString) {
            expires = date
            return
        }

        // Obsolete RFC 850 format
        fmt.dateFormat = "EEEE, dd-MMM-yy hh:mm:ss zzz"
        if let date = fmt.date(from: dateString) {
            expires = date
            return
        }

        // Obsolete ANSI C asctime() format
        fmt.dateFormat = "EEE MMM d hh:mm:s yyyy"
        if let date = fmt.date(from: dateString) {
            expires = date
            return
        }

        return nil
    }

    init?(headers: HTTPHeaders) {
        guard let str = headers.firstValue(name: .expires) else {
            return nil
        }

        self.init(dateString: str)
    }

    init(expires: Date) {
        self.expires = expires
    }

    /// Generates the header string for this instance.
    public func toString() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "EEE, dd MMM yyyy hh:mm:ss zzz"

        return fmt.string(from: expires)
    }
}
