final class FormURLKeyedEncoder<K>: KeyedEncodingContainerProtocol
    where K: CodingKey
{
    /// See KeyedEncodingContainerProtocol.Key
    typealias Key = K

    /// See KeyedEncodingContainerProtocol.codingPath
    var codingPath: [CodingKey]

    /// The data being encoded
    let partialData: PartialFormURLEncodedData

    init(partialData: PartialFormURLEncodedData, codingPath: [CodingKey]) {
        self.partialData = partialData
        self.codingPath = codingPath
    }

    /// See KeyedEncodingContainerProtocol.encode
    func encodeNil(forKey key: K) throws {
        partialData.set(nil, atPath: codingPath + [key])
    }

    /// See KeyedEncodingContainerProtocol.encode
    func encode(_ value: Bool, forKey key: K) throws {
        try encode(value.description, forKey: key)
    }

    /// See KeyedEncodingContainerProtocol.encode
    func encode(_ value: Int, forKey key: K) throws {
        try encode(value.description, forKey: key)
    }

    /// See KeyedEncodingContainerProtocol.encode
    func encode(_ value: Double, forKey key: K) throws {
        try encode(value.description, forKey: key)
    }

    /// See KeyedEncodingContainerProtocol.encode
    func encode(_ value: String, forKey key: K) throws {
        partialData.set(.string(value), atPath: codingPath + [key])
    }

    /// See KeyedEncodingContainerProtocol.encode
    func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        let encoder = _FormURLEncoder(partialData: partialData, codingPath: codingPath + [key])
        try value.encode(to: encoder)
    }

    /// See KeyedEncodingContainerProtocol.nestedContainer
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        let container = FormURLKeyedEncoder<NestedKey>(partialData: partialData, codingPath: codingPath + [key])
        return .init(container)
    }

    /// See KeyedEncodingContainerProtocol.nestedUnkeyedContainer
    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        fatalError()
    }

    /// See KeyedEncodingContainerProtocol.superEncoder
    func superEncoder() -> Encoder {
        let encoder = _FormURLEncoder(partialData: partialData, codingPath: codingPath)
        return encoder
    }

    /// See KeyedEncodingContainerProtocol.superEncoder
    func superEncoder(forKey key: K) -> Encoder {
        let encoder = _FormURLEncoder(partialData: partialData, codingPath: codingPath + [key])
        return encoder
    }

}
