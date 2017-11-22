internal final class LeafUnkeyedEncoder: UnkeyedEncodingContainer {
    var count: Int
    var codingPath: [CodingKey]
    var partialData: PartialLeafData

    init(codingPath: [CodingKey], partialData: PartialLeafData) {
        self.codingPath = codingPath
        self.partialData = partialData
        self.count = 0
    }

    func encodeNil() throws {
        partialData.set(to: .null, at: codingPath)
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        let container = LeafKeyedEncoder<NestedKey>(codingPath: codingPath, partialData: partialData)
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return LeafUnkeyedEncoder(codingPath: codingPath, partialData: partialData)
    }

    func superEncoder() -> Encoder {
        let index = ArrayKey(index: count)
        defer { count += 1 }
        return _LeafEncoder(partialData: partialData, codingPath: codingPath + [index])
    }

    func encode(_ value: Bool) throws {
        partialData.set(to: .bool(value), at: codingPath)
    }

    func encode(_ value: Int) throws {
        partialData.set(to: .int(value), at: codingPath)
    }

    func encode(_ value: Double) throws {
        partialData.set(to: .double(value), at: codingPath)
    }

    func encode(_ value: String) throws {
        partialData.set(to: .string(value), at: codingPath)
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        let encoder = _LeafEncoder(partialData: partialData, codingPath: codingPath)
        try value.encode(to: encoder)
    }
}

internal struct ArrayKey: CodingKey {
    var intValue: Int?
    var index: Int {
        return intValue!
    }

    init(index: Int) {
        self.intValue = index
    }

    init?(intValue: Int) {
        self.intValue = intValue
    }

    var stringValue: String {
        get { fatalError() }
        set { fatalError() }
    }

    init?(stringValue: String) {
        fatalError()
    }

}
