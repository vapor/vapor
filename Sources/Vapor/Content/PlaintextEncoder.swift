/// Encodes data as plaintext, utf8.
public struct PlaintextEncoder: ContentEncoder {
    /// Private encoder.
    private let encoder: _PlaintextEncoder
    
    /// The specific plaintext `MediaType` to use.
    private let contentType: HTTPMediaType
    
    /// Creates a new `PlaintextEncoder`.
    ///
    /// - parameters:
    ///     - contentType: Plaintext `MediaType` to use.
    ///                    Usually `.plainText` or `.html`.
    public init(_ contentType: HTTPMediaType = .plainText) {
        encoder = .init()
        self.contentType = contentType
    }
    
    /// `ContentEncoder` conformance.
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
    {
        try encodable.encode(to: encoder)
        guard let string = self.encoder.plaintext else {
            fatalError()
        }
        headers.contentType = self.contentType
        body.writeString(string)
    }
}

// MARK: Private

private final class _PlaintextEncoder: Encoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]
    public var plaintext: String?
    
    public init() {
        self.codingPath = []
        self.userInfo = [:]
        self.plaintext = nil
    }
    
    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        fatalError("Plaintext encoding does not support dictionaries.")
    }
    
    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("Plaintext encoding does not support arrays.")
    }
    
    public func singleValueContainer() -> SingleValueEncodingContainer {
        return DataEncodingContainer(encoder: self)
    }
}

private final class DataEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }
    
    let encoder: _PlaintextEncoder
    init(encoder: _PlaintextEncoder) {
        self.encoder = encoder
    }
    
    func encodeNil() throws {
        encoder.plaintext = nil
    }
    
    func encode(_ value: Bool) throws {
        encoder.plaintext = value.description
    }
    
    func encode(_ value: Int) throws {
        encoder.plaintext = value.description
    }
    
    func encode(_ value: Double) throws {
        encoder.plaintext = value.description
    }
    
    func encode(_ value: String) throws { encoder.plaintext = value }
    func encode(_ value: Int8) throws { try encode(Int(value)) }
    func encode(_ value: Int16) throws { try encode(Int(value)) }
    func encode(_ value: Int32) throws { try encode(Int(value)) }
    func encode(_ value: Int64) throws { try encode(Int(value)) }
    func encode(_ value: UInt) throws { try encode(Int(value)) }
    func encode(_ value: UInt8) throws { try encode(UInt(value)) }
    func encode(_ value: UInt16) throws { try encode(UInt(value)) }
    func encode(_ value: UInt32) throws { try encode(UInt(value)) }
    func encode(_ value: UInt64) throws { try encode(UInt(value)) }
    func encode(_ value: Float) throws { try encode(Double(value)) }
    func encode<T>(_ value: T) throws where T: Encodable {
        if let data = value as? Data {
            // special case for data
            if let utf8 = String(data: data, encoding: .utf8) {
                encoder.plaintext = utf8
            } else {
                encoder.plaintext = data.base64EncodedString()
            }
        } else {
            try value.encode(to: encoder)
        }
    }
}
