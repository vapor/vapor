import Foundation

internal struct RFC1123 {
    internal static let shared = RFC1123()
    internal let formatter: DateFormatter
    
    internal init() {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        self.formatter = formatter
    }
}

extension Date {
    internal var rfc1123: String {
        return RFC1123.shared.formatter.string(from: self)
    }
    
    internal init?(rfc1123: String) {
        guard let date = RFC1123.shared.formatter.date(from: rfc1123) else {
            return nil
        }
        
        self = date
    }
}
