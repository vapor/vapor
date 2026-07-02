import Foundation
import HTTPTypes

extension HTTPFields {
    /// Represents the HTTP `WWW-Authenticate` header.
    /// - See Also:
    /// [WWW-Authenticate](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/WWW-Authenticate)
    public struct WWWAuthenticate: ExpressibleByStringLiteral, Equatable, Sendable {
        /// The serialized header value.
        public let value: String

        /// Creates a `WWW-Authenticate` header from a serialized header value.
        public init(value: String) {
            self.value = value
        }

        public init(stringLiteral value: String) {
            self.init(value: value)
        }

        /// Creates a Basic authentication challenge.
        public static func basic(realm: String) -> WWWAuthenticate {
            .init(value: "Basic realm=\"\(realm.escapingHTTPQuotedString())\"")
        }
    }

    /// Gets or sets the value of the `WWW-Authenticate` header, if present.
    public var wwwAuthenticate: WWWAuthenticate? {
        get { self[.wwwAuthenticate].map(WWWAuthenticate.init(value:)) }
        set {
            if let new = newValue {
                self[.wwwAuthenticate] = new.value
            } else {
                self[.wwwAuthenticate] = nil
            }
        }
    }
}

private extension String {
    func escapingHTTPQuotedString() -> String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
