import Foundation
import libc


struct RFC1123 {
    static func now() -> String { return Date().rfc1123 }

    static let shared = RFC1123()
    var formatter: DateFormatter

    init() {
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
    }
}
