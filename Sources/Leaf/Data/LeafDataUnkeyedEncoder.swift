internal final class LeafDataUnkeyedEncoder: UnkeyedEncodingContainer {
    var count: Int
    var codingPath: [CodingKey]
    var partialData: PartialLeafData

    init(codingPath: [CodingKey], partialData: PartialLeafData) {
        self.codingPath = codingPath
        self.partialData = partialData
        self.count = 0
    }

    func encodeNil() throws {
        print("encode nil at \(codingPath)")
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        print("nestedContainer at \(codingPath)")
        fatalError()
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        print("nestedUnkeyedContainer at \(codingPath)")
        fatalError()
    }

    func superEncoder() -> Encoder {
        print("superEncoder at \(codingPath)")
        let index = ArrayKey(index: count)
        defer { count += 1 }
        return LeafDataEncoder(partialData: partialData, codingPath: codingPath + [index])
    }

    func encode(_ value: Bool) throws {
        print("encode \(value) at \(codingPath)")
    }

    func encode(_ value: Int) throws {
        print("encode \(value) at \(codingPath)")
    }

    func encode(_ value: Double) throws {
        print("encode \(value) at \(codingPath)")
    }

    func encode(_ value: String) throws {
        print("encode \(value) at \(codingPath)")
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        print("encode \(value) at \(codingPath)")
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
