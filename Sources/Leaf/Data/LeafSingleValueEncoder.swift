internal final class LeafSingleValueEncoder: SingleValueEncodingContainer {
    var codingPath: [CodingKey]
    var partialData: PartialLeafData

    init(codingPath: [CodingKey], partialData: PartialLeafData) {
        self.codingPath = codingPath
        self.partialData = partialData
    }

    func encodeNil() throws {
        partialData.set(to: .null, at: codingPath)
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
