import Foundation

/// An internal helper that formats cookie dates as RFC1123
internal struct RFC1123 {
    /// A static RFC1123 helper instance
    internal static let shared = RFC1123()
    
    /// The RFC1123 formatter
    internal let formatter: DateFormatter
    
    /// Creates a new RFC1123 helper
    internal init() {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        self.formatter = formatter
    }
}

extension Date {
    /// Formats a `Date` as RFC1123
    internal var rfc1123: String {
        return RFC1123.shared.formatter.string(from: self)
    }
    
    /// Creates a `Date` from an RFC1123 string
    internal init?(rfc1123: String) {
        guard let date = RFC1123.shared.formatter.date(from: rfc1123) else {
            return nil
        }
        
        self = date
    }
}
