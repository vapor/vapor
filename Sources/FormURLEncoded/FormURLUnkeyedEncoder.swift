final class FormURLUnkeyedEncoder: UnkeyedEncodingContainer {
    /// See UnkeyedEncodingContainer.codingPath
    var codingPath: [CodingKey]

    /// See UnkeyedEncodingContainer.count
    var count: Int

    /// The data being encoded
    let partialData: PartialFormURLEncodedData

    /// Converts the current count to a coding key
    var key: CodingKey {
        return ArrayKey(count)
    }

    /// Creates a new unkeyed encoder.
    init(partialData: PartialFormURLEncodedData, codingPath: [CodingKey]) {
        self.partialData = partialData
        self.codingPath = codingPath
        self.count = 0
    }

    /// See UnkeyedEncodingContainer.encodeNil
    func encodeNil() throws {
        partialData.set(nil, atPath: codingPath + [key])
    }

    /// See UnkeyedEncodingContainer.encode
    func encode(_ value: Bool) throws {
        try encode(value.description)
    }

    /// See UnkeyedEncodingContainer.encode
    func encode(_ value: Int) throws {
        try encode(value.description)
    }

    /// See UnkeyedEncodingContainer.encode
    func encode(_ value: Double) throws {
        try encode(value.description)
    }

    /// See UnkeyedEncodingContainer.encode
    func encode(_ value: String) throws {
        partialData.set(.string(value), atPath: codingPath + [key])
    }

    /// See UnkeyedEncodingContainer.encode
    func encode<T>(_ value: T) throws where T: Encodable {
        let encoder = _FormURLEncoder(partialData: partialData, codingPath: codingPath + [key])
        try value.encode(to: encoder)
    }

    /// See UnkeyedEncodingContainer.nestedContainer
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        let container = FormURLKeyedEncoder<NestedKey>(partialData: partialData, codingPath: codingPath + [key])
        return .init(container)
    }

    /// See UnkeyedEncodingContainer.nestedUnkeyedContainer
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return FormURLUnkeyedEncoder(partialData: partialData, codingPath: codingPath + [key])
    }

    /// See UnkeyedEncodingContainer.superEncoder
    func superEncoder() -> Encoder {
        let encoder = _FormURLEncoder(partialData: partialData, codingPath: codingPath + [key])
        count += 1
        return encoder
    }
}
