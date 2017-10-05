public final class SQLiteRowDecoder: Decoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]
    public let row: SQLiteRow

    public init(row: SQLiteRow) {
        self.row = row
        self.codingPath = []
        self.userInfo = [:]
    }

    public func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(DecodingContainer(decoder: self))
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("unimplemented")
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return DecodingContainer<NoKey>(decoder: self)
    }
}

public struct NoKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = ""
    }

    public init?(intValue: Int) {
        self.stringValue = ""
        self.intValue = nil
    }
}
