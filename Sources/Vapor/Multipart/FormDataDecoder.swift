/// Decodes `Decodable` types from `multipart/form-data` encoded `Data`.
///
/// See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
///
/// Seealso `MultipartParser` for more information about the `multipart` encoding.
public struct FormDataDecoder {
    /// Creates a new `FormDataDecoder`.
    public init() { }

    public func decode<D>(_ decodable: D.Type, from data: String, boundary: String) throws -> D
        where D: Decodable
    {
        return try self.decode(D.self, from: [UInt8](data.utf8), boundary: boundary)
    }

    /// Decodes a `Decodable` item from `Data` using the supplied boundary.
    ///
    ///     let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "123")
    ///
    /// - parameters:
    ///     - encodable: Generic `Decodable` type.
    ///     - boundary: Multipart boundary to used in the encoding.
    /// - throws: Any errors decoding the model with `Codable` or parsing the data.
    /// - returns: An instance of the decoded type `D`.
    public func decode<D>(_ decodable: D.Type, from data: [UInt8], boundary: String) throws -> D
        where D: Decodable
    {
        let parser = MultipartParser(boundary: boundary)

        var parts: [MultipartPart] = []
        var headers: HTTPHeaders = .init()
        var body: ByteBuffer = ByteBufferAllocator().buffer(capacity: 0)

        parser.onHeader = { (field, value) in
            headers.replaceOrAdd(name: field, value: value)
        }
        parser.onBody = { new in
            body.writeBuffer(&new)
        }
        parser.onPartComplete = {
            let part = MultipartPart(headers: headers, body: body)
            headers = [:]
            body = ByteBufferAllocator().buffer(capacity: 0)
            parts.append(part)
        }

        try parser.execute(data)
        let multipart = FormDataDecoderContext(parts: parts)
        let decoder = _FormDataDecoder(multipart: multipart, codingPath: [])
        return try D(from: decoder)
    }
}

// MARK: Private

private final class FormDataDecoderContext {
    var parts: [MultipartPart]
    init(parts: [MultipartPart]) {
        self.parts = parts
    }

    func decode<D>(_ decodable: D.Type, at codingPath: [CodingKey]) throws -> D where D: Decodable {
        guard let convertible = D.self as? MultipartPartConvertible.Type else {
            throw MultipartError.convertibleType(D.self)
        }

        let part: MultipartPart
        switch codingPath.count {
        case 1:
            let name = codingPath[0].stringValue
            guard let p = parts.firstPart(named: name) else {
                throw MultipartError.missingPart(name)
            }
            part = p
        case 2:
            let name = codingPath[0].stringValue + "[]"
            guard let offset = codingPath[1].intValue else {
                throw MultipartError.nesting
            }
            part = parts.allParts(named: name)[offset]
        default:
            throw MultipartError.nesting
        }

        guard let any = convertible.init(multipart: part) else {
            throw MultipartError.convertiblePart(D.self, part)
        }
        return any as! D
    }
}


private struct _FormDataDecoder: Decoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] {
        return [:]
    }
    let multipart: FormDataDecoderContext

    init(multipart: FormDataDecoderContext, codingPath: [CodingKey]) {
        self.multipart = multipart
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(_FormDataKeyedDecoder<Key>(multipart: multipart, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try _FormDataUnkeyedDecoder(multipart: multipart, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return _FormDataSingleValueDecoder(multipart: multipart, codingPath: codingPath)
    }
}

private struct _FormDataSingleValueDecoder: SingleValueDecodingContainer {
    var codingPath: [CodingKey]
    let multipart: FormDataDecoderContext

    init(multipart: FormDataDecoderContext, codingPath: [CodingKey]) {
        self.multipart = multipart
        self.codingPath = codingPath
    }

    func decodeNil() -> Bool {
        return false
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try multipart.decode(T.self, at: codingPath)
    }
}

private struct _FormDataKeyedDecoder<K>: KeyedDecodingContainerProtocol where K: CodingKey {
    var codingPath: [CodingKey]
    var allKeys: [K] {
        return multipart.parts
            .compactMap { $0.name }
            .compactMap { K(stringValue: $0) }
    }

    let multipart: FormDataDecoderContext

    init(multipart: FormDataDecoderContext, codingPath: [CodingKey]) {
        self.multipart = multipart
        self.codingPath = codingPath
    }

    func contains(_ key: K) -> Bool {
        return multipart.parts.contains { $0.name == key.stringValue }
    }

    func decodeNil(forKey key: K) throws -> Bool {
        return false
    }

    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T : Decodable {
        if T.self is MultipartPartConvertible.Type {
            return try multipart.decode(T.self, at: codingPath + [key])
        } else {
            let decoder = _FormDataDecoder(multipart: multipart, codingPath: codingPath + [key])
            return try T(from: decoder)
        }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        return KeyedDecodingContainer(_FormDataKeyedDecoder<NestedKey>(multipart: multipart, codingPath: codingPath + [key]))
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        return try _FormDataUnkeyedDecoder(multipart: multipart, codingPath: codingPath + [key])
    }

    func superDecoder() throws -> Decoder {
        return _FormDataDecoder(multipart: multipart, codingPath: codingPath)
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        return _FormDataDecoder(multipart: multipart, codingPath: codingPath + [key])
    }
}

private struct _FormDataUnkeyedDecoder: UnkeyedDecodingContainer {
    var codingPath: [CodingKey]
    var count: Int?
    var isAtEnd: Bool {
        return currentIndex >= count!
    }
    var currentIndex: Int
    var index: CodingKey {
        return BasicCodingKey.index(self.currentIndex)
    }

    let multipart: FormDataDecoderContext

    init(multipart: FormDataDecoderContext, codingPath: [CodingKey]) throws {
        self.multipart = multipart
        self.codingPath = codingPath

        let name: String
        switch codingPath.count {
        case 1: name = codingPath[0].stringValue
        default:
            throw MultipartError.nesting
        }
        let parts = multipart.parts.allParts(named: name + "[]")
        self.count = parts.count
        self.currentIndex = 0
    }

    mutating func decodeNil() throws -> Bool {
        return false
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        defer { currentIndex += 1 }
        if T.self is MultipartPartConvertible.Type {
            return try multipart.decode(T.self, at: codingPath + [index])
        } else {
            let decoder = _FormDataDecoder(multipart: multipart, codingPath: codingPath + [index])
            return try T(from: decoder)
        }
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        return KeyedDecodingContainer(_FormDataKeyedDecoder<NestedKey>(multipart: multipart, codingPath: codingPath + [index]))
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try _FormDataUnkeyedDecoder(multipart: multipart, codingPath: codingPath + [index])
    }

    mutating func superDecoder() throws -> Decoder {
        return _FormDataDecoder(multipart: multipart, codingPath: codingPath + [index])
    }


}
