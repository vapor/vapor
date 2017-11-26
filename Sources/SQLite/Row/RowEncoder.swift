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
        return KeyedEncodingContainer(RowEncodingContainer(encoder: self))
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("unsupported")
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError("unsupported")
    }
}
