#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes

extension HTTPFields {
    public struct Expires {
        /// The date represented by the header.
        public let expires: Date

        static func parse(_ dateString: String) -> Expires? {
            if let date = try? Date(dateString, strategy: .rfc1123) {
                return .init(expires: date)
            }
            return nil
        }

        init(expires: Date) {
            self.expires = expires
        }

        /// Generates the header string for this instance.
        public func serialize() -> String {
            expires.formatted(.rfc1123)
        }
    }

    /// Gets the value of the `Expires` header, if present.
    /// ### Note ###
    /// `Expires` is legacy and you should switch to using `CacheControl` if possible.
    public var expires: Expires? {
        get { self[.expires].flatMap(Expires.parse) }
        set {
            if let new = newValue?.serialize() {
                self[.expires] = new
            } else {
                self[.expires] = nil
            }
        }
    }
}
