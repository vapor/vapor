import Core
import Foundation
import HTTP

public final class HTMLEncoder: Encoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]
    public var html: Data?

    public init() {
        self.codingPath = []
        self.userInfo = [:]
        self.html = nil
    }

    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        fatalError("HTML encoding does not support nested dictionaries")
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("HTML encoding does not support nested arrays")
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return HTMLEncodingContainer(encoder: self)
    }
}

/// MARK: Container

internal final class HTMLEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }

    let encoder: HTMLEncoder
    init(encoder: HTMLEncoder) {
        self.encoder = encoder
    }

    func encodeNil() throws {
        encoder.html = nil
    }

    func encode(_ value: Bool) throws {
        encoder.html = value.description.data(using: .utf8)
    }

    func encode(_ value: Int) throws {
        encoder.html = value.description.data(using: .utf8)
    }

    func encode(_ value: Double) throws {
        encoder.html = value.description.data(using: .utf8)
    }

    func encode(_ value: String) throws {
        encoder.html = value.description.data(using: .utf8)
    }

    func encode<T: Encodable>(_ value: T) throws {
        if let data = value as? Data {
            encoder.html = data
        } else {
            try value.encode(to: encoder)
        }
    }
}

/// MARK: Content

extension HTMLEncoder: BodyEncoder {
    /// See BodyEncoder.encode
    public func encodeBody<T>(from encodable: T) throws -> HTTPBody where T: Encodable {
        try encodable.encode(to: self)
        guard let html = self.html else {
            throw "no html encoded"
        }
        return HTTPBody(html)
    }
}
