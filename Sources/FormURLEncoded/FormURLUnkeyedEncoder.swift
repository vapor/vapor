final class FormURLUnkeyedEncoder: UnkeyedEncodingContainer {
    var codingPath: [CodingKey]
    var count: Int
    let partialData: PartialFormURLEncodedData

    /// Converts the current count to a coding key
    var key: CodingKey {
        return ArrayKey(count)
    }

    init(partialData: PartialFormURLEncodedData, codingPath: [CodingKey]) {
        self.partialData = partialData
        self.codingPath = codingPath
        self.count = 0
    }

    func encodeNil() throws {
        <#code#>
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        <#code#>
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        <#code#>
    }

    /// See UnkeyedEncodingContainer.superEncoder
    func superEncoder() -> Encoder {
        let encoder = _FormURLEncoder(partialData: partialData, codingPath: codingPath + [key])
        count += 1
        return encoder
    }
}
