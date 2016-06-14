import Foundation
import libc

struct RFC1123 {
    static let shared = RFC1123()
    var formatter: DateFormatter

    init() {
        formatter = DateFormatter()
        formatter.locale = Locale(localeIdentifier: "en_US")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
    }
}

extension Date {
    public var rfc1123: String {
        return RFC1123.shared.formatter.string(from: self)
    }
}

extension Response {
    public static var date: String {
        return Date().rfc1123
    }
}
