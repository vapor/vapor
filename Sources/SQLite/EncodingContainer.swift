internal final class EncodingContainer<K: CodingKey>:
    KeyedEncodingContainerProtocol,
    UnkeyedEncodingContainer,
    SingleValueEncodingContainer
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

    func encodeNil() throws {
        fatalError("unimplemented")
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        fatalError("unimplemented")
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("unimplemented")
    }

    func superEncoder() -> Encoder {
        fatalError("unimplemented")
    }

    func encodeNil(forKey key: K) throws {
        fatalError("unimplemented")
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: K
    ) -> KeyedEncodingContainer<NestedKey> {
        fatalError("unimplemented")
    }

    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        fatalError("unimplemented")
    }

    func superEncoder(forKey key: K) -> Encoder {
        fatalError("unimplemented")
    }

    func encode(_ value: Bool) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Int) throws {
        encoder.data = .integer(value)
    }

    func encode(_ value: Int8) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Int16) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Int32) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Int64) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt8) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt16) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt32) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt64) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Float) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Double) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: String) throws {
        encoder.data = .text(value)
    }

    func encode<T: Encodable>(_ value: T) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Bool, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Int, forKey key: K) throws {
        encoder.row[key.stringValue] = .integer(value)
    }

    func encode(_ value: Int8, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Int16, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Int32, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Int64, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt8, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt16, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt32, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: UInt64, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Float, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: Double, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func encode(_ value: String, forKey key: K) throws {
        encoder.row[key.stringValue] = .text(value)
    }

    func encode<T: Encodable>(_ value: T, forKey key: K) throws {
        try value.encode(to: encoder)
    }
}


