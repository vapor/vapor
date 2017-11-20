import Core
import HTTP

public final class HTMLEncoder: Encoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]
    public var html: String?

    public init() {
        self.codingPath = []
        self.userInfo = [:]
        self.html = nil
    }

    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let encoder = UnsupportedEncodingContainer<Key>(encoder: self)
        return KeyedEncodingContainer(encoder)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnsupportedEncodingContainer<StringKey>(encoder: self)
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
        encoder.html = value.description
    }

    func encode(_ value: Int) throws {
        encoder.html = value.description
    }

    func encode(_ value: Double) throws {
        encoder.html = value.description
    }

    func encode(_ value: String) throws {
        encoder.html = value.description
    }

    func encode<T: Encodable>(_ value: T) throws {
        try value.encode(to: encoder)
    }
}

/// MARK: Content

extension HTMLEncoder: BodyEncoder {
    /// See BodyEncoder.encode
    public func encodeBody<T>(_ encodable: T) throws -> Body where T: Encodable {
        try encodable.encode(to: self)
        guard let html = self.html else {
            throw "no html encoded"
        }
        return Body(string: html)
    }
}
