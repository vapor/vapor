import Foundation
import libc


struct RFC1123 {
    static func now() -> String { return NSDate().rfc1123 }

    static let shared = RFC1123()
    var formatter: NSDateFormatter

    init() {
        formatter = NSDateFormatter()
        formatter.locale = NSLocale(identifier: "en_US")
        formatter.timeZone = NSTimeZone(abbreviation: "GMT")
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
    }
}
