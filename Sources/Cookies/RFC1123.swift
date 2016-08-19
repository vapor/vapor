import Foundation

public struct RFC1123 {
    public static let shared = RFC1123()
    public let formatter: DateFormatter

    public init() {
        formatter = DateFormatter()
        #if os(Linux)
            formatter.locale = Locale(localeIdentifier: "en_US")
        #else
            formatter.locale = Locale(identifier: "en_US")
        #endif
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
    }
}

extension Date {
    public var rfc1123: String {
        return RFC1123.shared.formatter.string(from: self)
    }

    public init?(rfc1123: String) {
        guard let date = RFC1123.shared.formatter.date(from: rfc1123) else {
            return nil
        }
        
        self = date
    }
}
