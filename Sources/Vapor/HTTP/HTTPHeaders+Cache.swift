extension HTTPHeaders {
    private enum CacheDateResponse {
        case set(Date?)
        case ignore
    }

    /// Determines when the cached data should be expired.
    /// - Parameter requestSentAt: Should be passed the `Date` when the request was sent.
    public func getCacheExpiration(requestSentAt: Date) -> Date? {
        // Cache-Control header takes priority over the Expires header
        if case let .set(date) = cacheControlDate(requestSentAt: requestSentAt) {
            return date
        }

        if let expires = expiresDate() {
            return expires
        }

        return nil
    }

    private func cacheControlDate(requestSentAt: Date) -> CacheDateResponse {
        guard let cacheControl = firstValue(name: .cacheControl) else {
            return .ignore
        }

        let pattern = #"^max-age=(\d+)$"#
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)

        var set = CharacterSet.whitespacesAndNewlines
        set.insert(",")

        var newDate: Date?

        let components = cacheControl
            .filter { !($0.isWhitespace || $0.isNewline) }
            .components(separatedBy: set)

        for value in components {
            if value == "no-store" {
                return .set(nil)
            }

            let nsRange = NSRange(value.startIndex ..< value.endIndex, in: value)

            guard let match = regex.firstMatch(in: value, options: [], range: nsRange),
                let range = Range(match.range(at: 1), in: value),
                let maxAge = TimeInterval(value[range]) else {
                    continue
            }

            guard maxAge != 0 else {
                return .set(nil)
            }

            // Don't immediately return as we may still find a no-store option.
            newDate = requestSentAt.addingTimeInterval(maxAge)
        }

        guard let desired = newDate else {
            return .ignore
        }

        return .set(desired)
    }

    private func expiresDate() -> Date? {
        guard let expires = firstValue(name: .expires) else { return nil }

        // https://tools.ietf.org/html/rfc7231#section-7.1.1.1
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)

        // Preferred format
        fmt.dateFormat = "EEE, dd MMM yyyy hh:mm:ss zzz"
        if let date = fmt.date(from: expires) {
            return date
        }

        // Obsolete RFC 850 format
        fmt.dateFormat = "EEEE, dd-MMM-yy hh:mm:ss zzz"
        if let date = fmt.date(from: expires) {
            return date
        }

        // Obsolete ANSI C asctime() format
        fmt.dateFormat = "EEE MMM d hh:mm:s yyyy"
        if let date = fmt.date(from: expires) {
            return date
        }

        return nil
    }
}
