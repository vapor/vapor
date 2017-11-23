final class FormURLSingleValueEncoder: SingleValueEncodingContainer {
    /// See SingleValueEncodingContainer.codingPath
    var codingPath: [CodingKey]

    /// The data being encoded
    let partialData: PartialFormURLEncodedData

    /// Creates a new single value encoder
    init(partialData: PartialFormURLEncodedData, codingPath: [CodingKey]) {
        self.partialData = partialData
        self.codingPath = codingPath
    }

    /// See SingleValueEncodingContainer.encodeNil
    func encodeNil() throws {
        partialData.set(nil, atPath: codingPath)
    }

    /// See SingleValueEncodingContainer.encode
    func encode(_ value: Bool) throws {
        try encode(value.description)
    }

    /// See SingleValueEncodingContainer.encode
    func encode(_ value: Int) throws {
        try encode(value.description)
    }

    /// See SingleValueEncodingContainer.encode
    func encode(_ value: Double) throws {
        try encode(value.description)
    }

    /// See SingleValueEncodingContainer.encode
    func encode(_ value: String) throws {
        partialData.set(.string(value), atPath: codingPath)
    }

    /// See SingleValueEncodingContainer.encode
    func encode<T>(_ value: T) throws where T: Encodable {
        let encoder = _FormURLEncoder(partialData: partialData, codingPath: codingPath)
        try value.encode(to: encoder)
    }
}
