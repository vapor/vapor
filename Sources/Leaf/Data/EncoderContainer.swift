internal struct ContextContainer<K: CodingKey>:
    KeyedEncodingContainerProtocol,
    UnkeyedEncodingContainer,
    SingleValueEncodingContainer
{
    typealias Key = K

    var count: Int

    var encoder: ContextEncoder
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }

    public init(encoder: ContextEncoder) {
        self.encoder = encoder
        self.count = 0
    }

    mutating func encodeNil() throws {
        fatalError("unimplemented")
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        fatalError("unimplemented")
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("unimplemented")
    }

    mutating func superEncoder() -> Encoder {
        fatalError("unimplemented")
    }

    mutating func encodeNil(forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: K
    ) -> KeyedEncodingContainer<NestedKey> {
        fatalError("unimplemented")
    }

    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        fatalError("unimplemented")
    }

    mutating func superEncoder(forKey key: K) -> Encoder {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Bool) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Bool, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int8) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int16) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int32) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int64) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt8) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt16) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt32) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt64) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Float) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Double) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: String) throws {
        fatalError("unimplemented")
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int, forKey key: K) throws {
        set(.int(value), forKey: key)
    }

    mutating func encode(_ value: Int8, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int16, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int32, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int64, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt8, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt16, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt32, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt64, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Float, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Double, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: String, forKey key: K) throws {
        set(.string(value), forKey: key)
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws {
        fatalError("unimplemented")
    }

    func set(_ value: Context, forKey key: K) {
        if var dict = encoder.context.dictionary {
            dict[key.stringValue] = value
            encoder.context = .dictionary(dict)
        }
    }
}
