/// Encodes data as plaintext, utf8.
public final class PlaintextEncoder: DataEncoder, HTTPMessageEncoder {
    /// Private encoder.
    private let encoder: _DataEncoder

    /// The specific plaintext `MediaType` to use.
    private let contentType: MediaType

    /// Creates a new `PlaintextEncoder`.
    ///
    /// - parameters:
    ///     - contentType: Plaintext `MediaType` to use.
    ///                    Usually `.plainText` or `.html`.
    public init(_ contentType: MediaType = .plainText) {
        encoder = .init()
        self.contentType = contentType
    }

    /// See `DataEncoder`.
    public func encode<E>(_ encodable: E) throws -> Data where E : Encodable {
        try encodable.encode(to: encoder)
        guard let string = encoder.plaintext else {
            throw VaporError(identifier: "plaintextEncode", reason: "The data could not be encoded as plaintext.")
        }
        return Data(string.utf8)
    }

    /// See `HTTPMessageEncoder`.
    public func encode<E, M>(_ encodable: E, to message: inout M, on worker: Worker) throws
        where E: Encodable, M: HTTPMessage
    {
        message.contentType = self.contentType
        message.body = try HTTPBody(data: encode(encodable))
    }
}

// MARK: Private

private final class _DataEncoder: Encoder {
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

    let encoder: _DataEncoder
    init(encoder: _DataEncoder) {
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
