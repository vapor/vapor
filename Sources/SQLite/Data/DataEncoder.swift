import Core

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
        let encoder = UnsupportedEncodingContainer<Key>(encoder: self)
        return KeyedEncodingContainer(encoder)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnsupportedEncodingContainer<StringKey>(encoder: self)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return DataEncodingContainer(encoder: self)
    }
}
