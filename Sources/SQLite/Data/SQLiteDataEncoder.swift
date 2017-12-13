import JunkDrawer

public final class SQLiteDataEncoder: Encoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]
    public var data: SQLiteData

    public init() {
        self.codingPath = []
        self.userInfo = [:]
        self.data = .null
    }

    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        fatalError("SQLite rows do not support nested dictionaries")
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("SQLite rows do not support nested arrays")
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return DataEncodingContainer(encoder: self)
    }
}
