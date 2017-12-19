internal final class RowEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol
{
    typealias Key = K

    var count: Int

    var encoder: SQLiteRowEncoder
    var codingPath: [CodingKey] {
        get { return encoder.codingPath }
    }

    public init(encoder: SQLiteRowEncoder) {
        self.encoder = encoder
        self.count = 0
    }

    func encode(_ value: Bool, forKey key: K) throws {
        encoder.row[key.stringValue] = .integer(value ? 1 : 0)
    }

    func encode(_ value: Int, forKey key: K) throws {
        encoder.row[key.stringValue] = .integer(value)
    }

    func encode(_ value: Double, forKey key: K) throws {
        encoder.row[key.stringValue] = .float(value)
    }

    func encode(_ value: String, forKey key: K) throws {
        encoder.row[key.stringValue] = .text(value)
    }

    func encode<T: Encodable>(_ value: T, forKey key: K) throws {
        let d = SQLiteDataEncoder()
        try value.encode(to: d)
        encoder.row[key.stringValue] = d.data
    }

    func encodeNil(forKey key: K) throws {
        encoder.row[key.stringValue] = .null
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: K
    ) -> KeyedEncodingContainer<NestedKey> {
        fatalError("SQLite rows do not support nested dictionaries")
    }

    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        fatalError("SQLite rows do not support nested arrays")
    }

    func superEncoder() -> Encoder {
        return encoder
    }

    func superEncoder(forKey key: K) -> Encoder {
        return encoder
    }
}


