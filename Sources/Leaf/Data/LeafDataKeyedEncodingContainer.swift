internal final class LeafDataKeyedEncoder<K>: KeyedEncodingContainerProtocol
    where K: CodingKey
{
    typealias Key = K

    var codingPath: [CodingKey]
    var partialData: PartialLeafData

    init(codingPath: [CodingKey], partialData: PartialLeafData) {
        self.codingPath = codingPath
        self.partialData = partialData
    }

    func superEncoder() -> Encoder {
        print("superEncoder at \(codingPath)")
        fatalError()
    }

    func encodeNil(forKey key: K) throws {
        print("encode nil at \(codingPath)")
        partialData.set(to: .null, at: codingPath)
    }

    func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type, forKey key: K
    ) -> KeyedEncodingContainer<NestedKey>
        where NestedKey : CodingKey {
        print("nestedContainer for key \(key) at \(codingPath)")
        fatalError()
    }

    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        print("nestedUnkeyedContainer for key \(key) at \(codingPath)")
        fatalError()
    }

    func superEncoder(forKey key: K) -> Encoder {
        print("superEncoder for key \(key) at \(codingPath)")
        return LeafDataEncoder(partialData: partialData, codingPath: codingPath + [key])
    }

    func encode(_ value: Bool, forKey key: K) throws {
        print("encode \(value) key \(key) at \(codingPath)")
        partialData.set(to: .bool(value), at: codingPath + [key])
    }

    func encode(_ value: Double, forKey key: K) throws {
        print("encode \(value) key \(key) at \(codingPath)")
        partialData.set(to: .double(value), at: codingPath + [key])
    }

    func encode(_ value: Int, forKey key: K) throws {
        print("encode \(value) key \(key) at \(codingPath)")
        partialData.set(to: .int(value), at: codingPath + [key])
    }

    func encode(_ value: String, forKey key: K) throws {
        print("encode \(value) key \(key) at \(codingPath)")
        partialData.set(to: .string(value), at: codingPath + [key])
    }

    func encode<T>(_ value: T, forKey key: K) throws
        where T: Encodable
    {
        print("encode \(value) key \(key) at \(codingPath)")
        let encoder = LeafDataEncoder(partialData: partialData, codingPath: codingPath + [key])
        try value.encode(to: encoder)
    }
}


