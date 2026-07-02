#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes

extension HTTPFields {
    /// Represents the HTTP `Last-Modified` header.
    /// - See Also:
    /// [Last-Modified](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Last-Modified)
    public struct LastModified {
        public var value: Date

        internal static func parse(_ dateString: String) -> LastModified? {
            if let date = try? Date(dateString, strategy: .rfc1123) {
                return .init(value: date)
            }
            return nil
        }

        public func serialize() -> String {
            value.formatted(.rfc1123)
        }
    }

    public var lastModified: LastModified? {
        get { self[.lastModified].flatMap(LastModified.parse) }
        set {
            if let new = newValue?.serialize() {
                self[.lastModified] = new
            } else {
                self[.lastModified] = nil
            }
        }
    }
}

extension HTTPFields.LastModified {
    /// Initialize a `Last-Modified` header with a date.
    public init(_ date: Date) {
        self.init(value: date)
    }
}
