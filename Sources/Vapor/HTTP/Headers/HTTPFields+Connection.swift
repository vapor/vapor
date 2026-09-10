public import HTTPTypes

extension HTTPFields {
    public struct Connection: ExpressibleByStringLiteral, Equatable, Sendable {
        public static let close: Self = "close"
        public static let keepAlive: Self = "keep-alive"

        public let value: String

        public init(value: String) {
            self.value = value
        }

        public init(stringLiteral value: String) {
            self.init(value: value)
        }
    }

    public var connection: Connection? {
        get {
            self[.connection].flatMap(Connection.init(value:))
        }
        set {
            if let value = newValue {
                self[.connection] = value.value
            } else {
                self[.connection] = nil
            }
        }
    }
}

extension HTTPFields {
    /// The connection-specific fields an intermediary must not forward.
    ///
    /// RFC 9110 §7.6.1. These describe the single hop they arrived on, not the message, so passing
    /// them along makes an origin server's framing and connection decisions look like our own.
    private static let hopByHopFieldNames: [HTTPField.Name] = [
        .connection,
        .transferEncoding,
        .trailer,
        .upgrade,
        .proxyAuthenticate,
        .proxyAuthorization,
        // Not among the `HTTPField.Name` constants, but valid tokens, so these never fail.
        HTTPField.Name("Keep-Alive")!,
        HTTPField.Name("TE")!,
    ]

    /// Removes the fields that belong to a single connection rather than to the message.
    ///
    /// Call this before forwarding a response received from somewhere else - proxying a
    /// ``ClientResponse``, say. Without it an origin server's `Connection: close` would close *our*
    /// client's connection, and its `Upgrade` would advertise a protocol switch this server never
    /// agreed to.
    ///
    /// `Connection` itself names further fields that are hop-by-hop for that hop, so those are
    /// removed too.
    public mutating func removeHopByHopFields() {
        // Read before `Connection` is itself removed below.
        if let connection = self[.connection] {
            for name in connection.split(separator: ",") {
                let trimmed = name.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed()
                if let field = HTTPField.Name(String(trimmed)) {
                    self[field] = nil
                }
            }
        }
        for name in Self.hopByHopFieldNames {
            self[name] = nil
        }
    }
}
