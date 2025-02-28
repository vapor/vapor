import HTTPTypes

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
