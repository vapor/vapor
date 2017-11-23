final class FormURLUnkeyedDecoder: UnkeyedDecodingContainer {
    /// The data being decoded
    let data: FormURLEncodedData

    /// See KeyedDecodingContainerProtocol.codingPath
    var codingPath: [CodingKey]

    /// See UnkeyedDecodingContainer.count
    var count: Int? {
        guard let array = data.get(at: codingPath)?.array else {
            return nil
        }
        return array.count
    }

    /// See UnkeyedDecodingContainer.isAtEnd
    var isAtEnd: Bool {
        guard let count = self.count else {
            return false
        }
        return currentIndex >= count
    }

    /// See UnkeyedDecodingContainer.currentIndex
    var currentIndex: Int

    /// Converts the current index to a coding key
    var key: CodingKey {
        return ArrayKey(currentIndex)
    }

    /// Create a new FormURLKeyedDecoder
    init(data: FormURLEncodedData, codingPath: [CodingKey]) {
        self.data = data
        self.codingPath = codingPath
        currentIndex = 0
    }

    /// See UnkeyedDecodingContainer.decodeNil
    func decodeNil() throws -> Bool {
        return data.get(at: codingPath + [key]) == nil
    }

    /// See UnkeyedDecodingContainer.decode
    func decode(_ type: Bool.Type) throws -> Bool {
        guard let value = try data.require(type, atPath: codingPath + [key]).string.flatMap({ Bool($0) }) else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See UnkeyedDecodingContainer.decode
    func decode(_ type: Int.Type) throws -> Int {
        guard let value = try data.require(type, atPath: codingPath + [key]).string.flatMap({ Int($0) }) else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See UnkeyedDecodingContainer.decode
    func decode(_ type: Double.Type) throws -> Double {
        guard let value = try data.require(type, atPath: codingPath + [key]).string.flatMap({ Double($0) }) else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See UnkeyedDecodingContainer.decode
    func decode(_ type: String.Type) throws -> String {
        guard let value = try data.require(type, atPath: codingPath + [key]).string else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See UnkeyedDecodingContainer.decode
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let decoder = _FormURLDecoder(data: data, codingPath: codingPath + [key])
        return try T(from: decoder)
    }

    /// See UnkeyedDecodingContainer.nestedContainer
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        let container = FormURLKeyedDecoder<NestedKey>(data: data, codingPath: codingPath + [key])
        return .init(container)
    }

    /// See UnkeyedDecodingContainer.nestedUnkeyedContainer
    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return FormURLUnkeyedDecoder(data: data, codingPath: codingPath + [key])
    }

    /// See UnkeyedDecodingContainer.superDecoder
    func superDecoder() throws -> Decoder {
        let decoder = _FormURLDecoder(data: data, codingPath: codingPath + [key])
        currentIndex += 1
        return decoder
    }

}
