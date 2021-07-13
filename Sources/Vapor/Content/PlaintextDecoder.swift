/// Decodes data as plaintext, utf8.
public struct PlaintextDecoder: ContentDecoder {

    public init() { }

    /// `ContentDecoder` conformance.
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
        where D : Decodable
    {
        let string = body.getString(at: body.readerIndex, length: body.readableBytes)
        return try D(from: _PlaintextDecoder(plaintext: string))
    }
}

// MARK: Private

private final class _PlaintextDecoder: Decoder {

    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    let plaintext: String?

    init(plaintext: String?) {
        self.codingPath = []
        self.userInfo = [:]
        self.plaintext = plaintext
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        throw DecodingError.typeMismatch(type, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Plaintext decoding does not support dictionaries."
        ))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Plaintext decoding does not support arrays."
        ))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        DataDecodingContainer(decoder: self)
    }
}

private final class DataDecodingContainer: SingleValueDecodingContainer {

    var codingPath: [CodingKey] { decoder.codingPath }

    let decoder: _PlaintextDecoder
    init(decoder: _PlaintextDecoder) {
        self.decoder = decoder
    }

    func decodeNil() -> Bool {
        if let plaintext = decoder.plaintext {
            return plaintext.isEmpty
        }
        return true
    }

    func losslessDecode<L: LosslessStringConvertible>(_ type: L.Type) throws -> L {
        if let plaintext = decoder.plaintext, let decoded = L(plaintext) {
            return decoded
        }
        throw DecodingError.dataCorruptedError(
            in: self,
            debugDescription: "Failed to get \(type) from \"\(decoder.plaintext ?? "")\""
        )
    }

    func decode(_ type: Bool.Type) throws -> Bool { try losslessDecode(type) }
    func decode(_ type: String.Type) throws -> String { decoder.plaintext ?? "" }
    func decode(_ type: Double.Type) throws -> Double { try losslessDecode(type) }
    func decode(_ type: Float.Type) throws -> Float { try losslessDecode(type) }
    func decode(_ type: Int.Type) throws -> Int { try losslessDecode(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try losslessDecode(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try losslessDecode(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try losslessDecode(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try losslessDecode(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try losslessDecode(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try losslessDecode(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try losslessDecode(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try losslessDecode(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try losslessDecode(type) }
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        throw DecodingError.typeMismatch(type, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Plaintext decoding does not support nested types."
        ))
    }
}
