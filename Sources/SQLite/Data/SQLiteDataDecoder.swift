public final class SQLiteDataDecoder: Decoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]
    public let data: SQLiteData

    public init(data: SQLiteData) {
        self.codingPath = []
        self.userInfo = [:]
        self.data = data
    }

    public func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        fatalError("unsupported")
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("unsupported")
    }

    public func singleValueContainer() -> SingleValueDecodingContainer {
        return DataDecodingContainer(decoder: self)
    }
}

