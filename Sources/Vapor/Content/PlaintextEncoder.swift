import CodableKit
import Foundation

/// Encodes data as plaintext, utf8.
public final class PlaintextEncoder: DataEncoder, HTTPBodyEncoder {
    fileprivate let encoder: _DataEncoder

    /// Creates a new data encoder
    public init() {
        encoder = .init()
    }

    /// See `DataEncoder.encode(_:)`
    public func encode<E>(_ encodable: E) throws -> Data where E : Encodable {
        try encodable.encode(to: encoder)
        guard let data = encoder.data else {
            throw VaporError(identifier: "dataEncoding", reason: "An unknown error caused the data not to be encoded", source: .capture())
        }
        return data
    }

    /// See `HTTPBodyEncoder.encode(from:)`
    public func encodeBody<E>(from encodable: E) throws -> HTTPBody where E : Encodable {
        return try HTTPBody(data: encode(encodable))
    }
}

/// MARK: Private

fileprivate final class _DataEncoder: Encoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]
    public var data: Data?

    public init() {
        self.codingPath = []
        self.userInfo = [:]
        self.data = nil
    }

    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        fatalError("HTML encoding does not support nested dictionaries")
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("HTML encoding does not support nested arrays")
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return DataEncodingContainer(encoder: self)
    }
}

fileprivate final class DataEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }

    let encoder: _DataEncoder
    init(encoder: _DataEncoder) {
        self.encoder = encoder
    }

    func encodeNil() throws {
        encoder.data = nil
    }

    func encode(_ value: Bool) throws {
        if let data = value.description.data(using: .utf8) {
            encoder.data = data
        }
    }

    func encode(_ value: Int) throws {
        if let data = value.description.data(using: .utf8) {
            encoder.data = data
        }
    }

    func encode(_ value: Double) throws {
        if let data = value.description.data(using: .utf8) {
            encoder.data = data
        }
    }

    func encode(_ value: String) throws { encoder.data = Data(value.utf8) }
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

    func encode<T: Encodable>(_ value: T) throws {
        if let data = value as? Data {
            encoder.data = data
        } else {
            try value.encode(to: encoder)
        }
    }
}
