/// Encodes `Encodable` items to `multipart/form-data` encoded `Data`.
///
/// See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
///
/// Seealso `MultipartParser` for more information about the `multipart` encoding.
public struct FormDataEncoder {
    /// Creates a new `FormDataEncoder`.
    public init() { }

    public func encode<E>(_ encodable: E, boundary: String) throws -> String
        where E: Encodable
    {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        try self.encode(encodable, boundary: boundary, into: &buffer)
        return String(decoding: buffer.readableBytesView, as: UTF8.self)
    }

    /// Encodes an `Encodable` item to `Data` using the supplied boundary.
    ///
    ///     let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
    ///     let data = try FormDataEncoder().encode(a, boundary: "123")
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` item.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    /// - throws: Any errors encoding the model with `Codable` or serializing the data.
    /// - returns: `multipart/form-data`-encoded `Data`.
    public func encode<E>(_ encodable: E, boundary: String, into buffer: inout ByteBuffer) throws
        where E: Encodable
    {
        let multipart = FormDataEncoderContext()
        let encoder = _FormDataEncoder(multipart: multipart, codingPath: [])
        try encodable.encode(to: encoder)
        try MultipartSerializer().serialize(parts: multipart.parts, boundary: boundary, into: &buffer)
    }
}

// MARK: Private

private final class FormDataEncoderContext {
    var parts: [MultipartPart]
    init() {
        self.parts = []
    }

    func encode<E>(_ encodable: E, at codingPath: [CodingKey]) throws where E: Encodable {
        guard let convertible = encodable as? MultipartPartConvertible else {
            throw MultipartError.convertibleType(E.self)
        }

        guard var part = convertible.multipart else {
            throw MultipartError.convertibleType(E.self)
        }
        
        switch codingPath.count {
        case 1: part.name = codingPath[0].stringValue
        case 2:
            guard codingPath[1].intValue != nil else {
                throw MultipartError.nesting
            }
            part.name = codingPath[0].stringValue + "[]"
        default:
            throw MultipartError.nesting
        }
        self.parts.append(part)
    }
}

private struct _FormDataEncoder: Encoder {
    let codingPath: [CodingKey]
    let multipart: FormDataEncoderContext
    var userInfo: [CodingUserInfoKey: Any] {
        return [:]
    }

    init(multipart: FormDataEncoderContext, codingPath: [CodingKey]) {
        self.multipart = multipart
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return KeyedEncodingContainer(_FormDataKeyedEncoder(multipart: multipart, codingPath: codingPath))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return _FormDataUnkeyedEncoder(multipart: multipart, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return _FormDataSingleValueEncoder(multipart: multipart, codingPath: codingPath)
    }
}

private struct _FormDataSingleValueEncoder: SingleValueEncodingContainer {
    let multipart: FormDataEncoderContext
    var codingPath: [CodingKey]

    init(multipart: FormDataEncoderContext, codingPath: [CodingKey]) {
        self.multipart = multipart
        self.codingPath = codingPath
    }

    mutating func encodeNil() throws {
        // do nothing
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        try multipart.encode(value, at: codingPath)
    }
}

private struct _FormDataKeyedEncoder<K>: KeyedEncodingContainerProtocol where K: CodingKey {
    let multipart: FormDataEncoderContext
    var codingPath: [CodingKey]

    init(multipart: FormDataEncoderContext, codingPath: [CodingKey]) {
        self.multipart = multipart
        self.codingPath = codingPath
    }

    mutating func encodeNil(forKey key: K) throws {
        // ignore
    }

    mutating func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        if value is MultipartPartConvertible {
            try multipart.encode(value, at: codingPath + [key])
        } else {
            let encoder = _FormDataEncoder(multipart: multipart, codingPath: codingPath + [key])
            try value.encode(to: encoder)
        }
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        return KeyedEncodingContainer(_FormDataKeyedEncoder<NestedKey>(multipart: multipart, codingPath: codingPath + [key]))
    }

    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        return _FormDataUnkeyedEncoder(multipart: multipart, codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> Encoder {
        return _FormDataEncoder(multipart: multipart, codingPath: codingPath)
    }

    mutating func superEncoder(forKey key: K) -> Encoder {
        return _FormDataEncoder(multipart: multipart, codingPath: codingPath + [key])
    }
}

private struct _FormDataUnkeyedEncoder: UnkeyedEncodingContainer {
    var count: Int
    let multipart: FormDataEncoderContext
    var codingPath: [CodingKey]
    var index: CodingKey {
        return BasicCodingKey.index(0)
    }

    init(multipart: FormDataEncoderContext, codingPath: [CodingKey]) {
        self.multipart = multipart
        self.codingPath = codingPath
        self.count = 0
    }

    mutating func encodeNil() throws {
        // ignore
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        let encoder = _FormDataEncoder(multipart: multipart, codingPath: codingPath + [index])
        try value.encode(to: encoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        return KeyedEncodingContainer(_FormDataKeyedEncoder<NestedKey>(multipart: multipart, codingPath: codingPath + [index]))
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return _FormDataUnkeyedEncoder(multipart: multipart, codingPath: codingPath + [index])
    }

    mutating func superEncoder() -> Encoder {
        return _FormDataEncoder(multipart: multipart, codingPath: codingPath + [index])
    }
}
