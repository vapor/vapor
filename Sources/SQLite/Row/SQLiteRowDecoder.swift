import CodableKit

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
        fatalError("unsupported")
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return DecodingContainer<BasicKey>(decoder: self)
    }
}
