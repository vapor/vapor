/// Encodes `Encodable` objects to plaintext strings.
public final class PlaintextEncoder: DataEncoder, HTTPBodyEncoder {
    /// The internal encoder.
    fileprivate let encoder: _PlaintextEncoder

    /// Creates a new data encoder
    public init() {
        encoder = .init()
    }

    /// See `DataEncoder.encode(_:)`
    public func encode<E>(_ encodable: E) throws -> Data where E : Encodable {
        try encodable.encode(to: encoder)
        guard let plaintext = encoder.plaintext else {
            throw VaporError(identifier: "dataEncoding", reason: "An unknown error caused the data not to be encoded", source: .capture())
        }
        return Data(plaintext.utf8)
    }

    /// See `HTTPBodyEncoder.encode(from:)`
    public func encodeBody<E>(from encodable: E) throws -> HTTPBody where E : Encodable {
        return try HTTPBody(data: encode(encodable))
    }
}

/// Private encoder implementation.
fileprivate final class _PlaintextEncoder: Encoder, SingleValueEncodingContainer {
    public var codingPath: [CodingKey] {
        return []
    }

    public var userInfo: [CodingUserInfoKey: Any] {
        return [:]
    }

    public var plaintext: String?
    public init() { }

    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        fatalError("HTML encoding does not support nested dictionaries")
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("HTML encoding does not support nested arrays")
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }

    func encodeNil() throws {
        plaintext = nil
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        plaintext = "\(value)"
    }
}
