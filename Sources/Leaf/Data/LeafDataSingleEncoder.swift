internal final class LeafDataSingleEncoder: SingleValueEncodingContainer {
    var codingPath: [CodingKey]
    var partialData: PartialLeafData

    init(codingPath: [CodingKey], partialData: PartialLeafData) {
        self.codingPath = codingPath
        self.partialData = partialData
    }

    func encodeNil() throws {
        print("encode nil at \(codingPath)")
    }

    func encode(_ value: Bool) throws {
        print("encode \(value) at \(codingPath)")
    }

    func encode(_ value: Int) throws {
        print("encode \(value) at \(codingPath)")
    }

    func encode(_ value: Double) throws {
        print("encode \(value) at \(codingPath)")
        partialData.set(to: .double(value), at: codingPath)
    }

    func encode(_ value: String) throws {
        print("encode \(value) at \(codingPath)")
        partialData.set(to: .string(value), at: codingPath)
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        print("encode \(value) at \(codingPath)")
    }
}
