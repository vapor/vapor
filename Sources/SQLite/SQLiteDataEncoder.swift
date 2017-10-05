public final class SQLiteRowEncoder: Encoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]
    public var row: SQLiteRow

    public init() {
        self.codingPath = []
        self.userInfo = [:]
        self.row = SQLiteRow(fields: [:])
    }

    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer(EncodingContainer(encoder: self))
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        return EncodingContainer<NoKey>(encoder: self)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return EncodingContainer<NoKey>(encoder: self)
    }
}
