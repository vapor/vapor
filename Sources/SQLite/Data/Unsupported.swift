final class UnsupportedEncodingContainer<K: CodingKey> {
    let encoder: Encoder
    init(encoder: Encoder) {
        self.encoder = encoder
    }
}

// MARK: Single

extension UnsupportedEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] {
        return []
    }

    func encodeNil() throws {
        throw "unsupported"
    }

    func encode(_ value: Bool) throws {
        throw "unsupported"
    }

    func encode(_ value: Int) throws {
        throw "unsupported"
    }

    func encode(_ value: Int8) throws {
        throw "unsupported"
    }

    func encode(_ value: Int16) throws {
        throw "unsupported"
    }

    func encode(_ value: Int32) throws {
        throw "unsupported"
    }

    func encode(_ value: Int64) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt8) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt16) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt32) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt64) throws {
        throw "unsupported"
    }

    func encode(_ value: Float) throws {
        throw "unsupported"
    }

    func encode(_ value: Double) throws {
        throw "unsupported"
    }

    func encode(_ value: String) throws {
        throw "unsupported"
    }

    func encode<T: Encodable>(_ value: T) throws {
        throw "unsupported"
    }
}

// MARK: Unkeyed

extension UnsupportedEncodingContainer: UnkeyedEncodingContainer {
    var count: Int {
        return 0
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError("unsupported")
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return self
    }

    func superEncoder() -> Encoder {
        return encoder
    }
}

// MARK: Keyed

extension UnsupportedEncodingContainer: KeyedEncodingContainerProtocol {
    typealias Key = K

    func encodeNil(forKey key: Key) throws {
        throw "unsupported"
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        fatalError("unsupported")
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return self
    }

    func superEncoder(forKey key: Key) -> Encoder {
        return encoder
    }

    func encode(_ value: Bool, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: Int, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: Int8, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: Int16, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: Int32, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: Int64, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt8, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt16, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt32, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: UInt64, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: Float, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: Double, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode(_ value: String, forKey key: Key) throws {
        throw "unsupported"
    }

    func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        throw "unsupported"
    }
}

