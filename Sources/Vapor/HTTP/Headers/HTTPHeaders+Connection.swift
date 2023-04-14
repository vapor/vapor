import NIOHTTP1

extension HTTPHeaders {
    public struct Connection: Sendable, ExpressibleByStringLiteral, Equatable {
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
            self.first(name: .connection).flatMap(Connection.init(value:))
        }
        set {
            if let value = newValue {
                self.replaceOrAdd(name: .connection, value: value.value)
            } else {
                self.remove(name: .connection)
            }
        }
    }
}
