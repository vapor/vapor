final class FormURLSingleValueDecoder: SingleValueDecodingContainer {
    /// The data being decoded
    let data: FormURLEncodedData

    /// See SingleValueDecodingContainer.codingPath
    var codingPath: [CodingKey]

    /// Creates a new form urlencoded single value decoder
    init(data: FormURLEncodedData, codingPath: [CodingKey]) {
        self.data = data
        self.codingPath = codingPath
    }

    /// See SingleValueDecodingContainer.decodeNil
    func decodeNil() -> Bool {
        return data.get(at: codingPath) == nil
    }

    /// See SingleValueDecodingContainer.decode
    func decode(_ type: Bool.Type) throws -> Bool {
        guard let value = try data.require(type, atPath: codingPath).string.flatMap({ Bool($0) }) else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See SingleValueDecodingContainer.decode
    func decode(_ type: Int.Type) throws -> Int {
        guard let value = try data.require(type, atPath: codingPath).string.flatMap({ Int($0) }) else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See SingleValueDecodingContainer.decode
    func decode(_ type: Double.Type) throws -> Double {
        guard let value = try data.require(type, atPath: codingPath).string.flatMap({ Double($0) }) else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See SingleValueDecodingContainer.decode
    func decode(_ type: String.Type) throws -> String {
        guard let value = try data.require(type, atPath: codingPath).string else {
            throw DecodingError.typeMismatch(type, atPath: codingPath)
        }
        return value
    }

    /// See SingleValueDecodingContainer.decode
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let decoder = _FormURLDecoder(data: data, codingPath: codingPath)
        return try T(from: decoder)
    }
}
