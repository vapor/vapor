import Core
import Foundation
import HTTP

fileprivate final class _HTMLEncoder: Encoder {
    fileprivate var codingPath: [CodingKey]
    fileprivate var userInfo: [CodingUserInfoKey: Any]
    fileprivate var html: Body?

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

fileprivate final class HTMLEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }

    let encoder: _HTMLEncoder
    init(encoder: _HTMLEncoder) {
        self.encoder = encoder
    }

    func encodeNil() throws {
        encoder.html = nil
    }

    func encode(_ value: Bool) throws {
        encoder.html = Body(string: value.description)
    }

    func encode(_ value: Int) throws {
        encoder.html = Body(string: value.description)
    }

    func encode(_ value: Double) throws {
        encoder.html = Body(string: value.description)
    }

    func encode(_ value: String) throws {
        encoder.html = Body(string: value)
    }

    func encode<T: Encodable>(_ value: T) throws {
        if let data = value as? Data {
            encoder.html = Body(data)
        } else {
            try value.encode(to: encoder)
        }
    }
}

/// MARK: Content

public struct HTMLEncoder: BodyEncoder {
    public init() {}
    
    /// See BodyEncoder.encode
    public func encodeBody<T>(_ encodable: T) throws -> Body where T: Encodable {
        // Performant shortcut
        if let string = encodable as? String {
            return Body(string: string)
        }
        
        let encoder = _HTMLEncoder()
        try encodable.encode(to: encoder)
        guard let html = encoder.html else {
            throw "no html encoded"
        }
        
        return html
    }
}
