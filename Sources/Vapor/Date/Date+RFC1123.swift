import Foundation

extension Date {
    public var rfc1123: String {
        return RFC1123.shared.formatter.string(from: self)
    }
}
