import CodableKit
import Foundation

/// Encodes encodable items to data.
public final class DataEncoder {
    fileprivate let encoder: _DataEncoder

    /// Creates a new data encoder
    public init() {
        encoder = .init()
    }

    /// Encodes the object to data
    public func encode<E>(_ encodable: E) throws -> HTTPBody
        where E: Encodable
    {
        try encodable.encode(to: encoder)
        guard let body = encoder.body else {
            throw VaporError(identifier: "dataEncoding", reason: "An unknown error caused the data not to be encoded", source: .capture())
        }
        return body
    }
}

fileprivate final class _DataEncoder: Encoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]
    public var body: HTTPBody?

    public init() {
        self.codingPath = []
        self.userInfo = [:]
        self.body = nil
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

/// MARK: Container

fileprivate final class DataEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }

    let encoder: _DataEncoder
    init(encoder: _DataEncoder) {
        self.encoder = encoder
    }

    func encodeNil() throws {
        encoder.body = nil
    }

    func encode(_ value: Bool) throws {
        if let data = value.description.data(using: .utf8) {
            encoder.body = HTTPBody(data: data)
        }
    }

    func encode(_ value: Int) throws {
        if let data = value.description.data(using: .utf8) {
            encoder.body = HTTPBody(data: data)
        }
    }

    func encode(_ value: Double) throws {
        if let data = value.description.data(using: .utf8) {
            encoder.body = HTTPBody(data: data)
        }
    }

    func encode(_ value: String) throws {
        encoder.body = HTTPBody(string: value)
    }

    func encode(_ value: Int8) throws {
        try encode(Int(value))
    }

    func encode(_ value: Int16) throws {
        try encode(Int(value))
    }

    func encode(_ value: Int32) throws {
        try encode(Int(value))
    }

    func encode(_ value: Int64) throws {
        try encode(Int(value))
    }

    func encode(_ value: UInt) throws {
        try encode(Int(value))
    }

    func encode(_ value: UInt8) throws {
        try encode(UInt(value))
    }

    func encode(_ value: UInt16) throws {
        try encode(UInt(value))
    }

    func encode(_ value: UInt32) throws {
        try encode(UInt(value))
    }

    func encode(_ value: UInt64) throws {
        try encode(UInt(value))
    }

    func encode(_ value: Float) throws {
        try encode(Double(value))
    }

    func encode<T: Encodable>(_ value: T) throws {
        if let data = value as? Data {
            encoder.body = HTTPBody(data: data)
        } else {
            try value.encode(to: encoder)
        }
    }
}

/// MARK: Content

extension DataEncoder: BodyEncoder {
    public func encodeBody<T>(from encodable: T) throws -> HTTPBody where T : Encodable {
        return try self.encode(encodable)
    }
}

