final class FormURLKeyedDecoder<K>: KeyedDecodingContainerProtocol
    where K: CodingKey
{
    /// See KeyedDecodingContainerProtocol.Key
    typealias Key = K

    /// The data being decoded
    let data: FormURLEncodedData

    /// See KeyedDecodingContainerProtocol.codingPath
    var codingPath: [CodingKey]

    /// See KeyedDecodingContainerProtocol.allKeys
    var allKeys: [K] {
        guard let dictionary = data.get(at: codingPath)?.dictionary else {
            return []
        }
        return dictionary.keys.flatMap { K(stringValue: $0) }
    }

    /// Create a new FormURLKeyedDecoder
    init(data: FormURLEncodedData, codingPath: [CodingKey]) {
        self.data = data
        self.codingPath = codingPath
    }

    /// See KeyedDecodingContainerProtocol.contains
    func contains(_ key: K) -> Bool {
        return data.get(at: codingPath)?.dictionary?[key.stringValue] != nil
    }

    /// See KeyedDecodingContainerProtocol.decodeNil
    func decodeNil(forKey key: K) throws -> Bool {
        return data.get(at: codingPath + [key]) == nil
    }

    /// See KeyedDecodingContainerProtocol.decode
    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        guard let value = try data.require(type, atPath: codingPath + [key]).string.flatMap({ Bool($0) }) else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See KeyedDecodingContainerProtocol.decode
    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        guard let value = try data.require(type, atPath: codingPath + [key]).string.flatMap({ Int($0) }) else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See KeyedDecodingContainerProtocol.decode
    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        guard let value = try data.require(type, atPath: codingPath + [key]).string.flatMap({ Double($0) }) else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See KeyedDecodingContainerProtocol.decode
    func decode(_ type: String.Type, forKey key: K) throws -> String {
        guard let value = try data.require(type, atPath: codingPath + [key]).string else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See KeyedDecodingContainerProtocol.decode
    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
        let decoder = _FormURLDecoder(data: data, codingPath: codingPath + [key])
        return try T(from: decoder)
    }

    /// See KeyedDecodingContainerProtocol.nestedContainer
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        let container = FormURLKeyedDecoder<NestedKey>(data: data, codingPath: codingPath + [key])
        return .init(container)
    }

    /// See KeyedDecodingContainerProtocol.nestedUnkeyedContainer
    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        return FormURLUnkeyedDecoder(data: data, codingPath: codingPath + [key])
    }

    /// See KeyedDecodingContainerProtocol.superDecoder
    func superDecoder() throws -> Decoder {
        return _FormURLDecoder(data: data, codingPath: codingPath)
    }

    /// See KeyedDecodingContainerProtocol.superDecoder
    func superDecoder(forKey key: K) throws -> Decoder {
        let decoder = _FormURLDecoder(data: data, codingPath: codingPath + [key])
        return decoder
    }
}
