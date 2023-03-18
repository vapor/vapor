import Foundation
import NIOCore
import NIOHTTP1

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
        self.encoder = .init()
        self.contentType = contentType
    }
    
    /// `ContentEncoder` conformance.
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
    {
        var container = self.encoder.singleValueContainer()
        try container.encode(encodable)

        guard let string = self.encoder.plaintext else {
            throw EncodingError.invalidValue(encodable, .init(codingPath: [], debugDescription: "Nothing was encoded!"))
        }
        headers.contentType = self.contentType
        body.writeString(string)
    }
}

// MARK: Private

private final class _PlaintextEncoder: Encoder, SingleValueEncodingContainer {
    public var codingPath: [CodingKey] = []
    public var userInfo: [CodingUserInfoKey: Any]
    public var plaintext: String?
    
    public init(userInfo: [CodingUserInfoKey: Any] = [:]) { self.userInfo = userInfo }
    
    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> { .init(FailingEncoder().container(keyedBy: Key.self)) }
    public func unkeyedContainer() -> UnkeyedEncodingContainer { FailingEncoder() }
    public func singleValueContainer() -> SingleValueEncodingContainer { self }

    func encodeNil() throws { self.plaintext = nil }
    func encode(_ value: Bool) throws { self.plaintext = value.description }
    func encode(_ value: Int) throws { self.plaintext = value.description }
    func encode(_ value: Double) throws { self.plaintext = value.description }
    func encode(_ value: String) throws { self.plaintext = value }
    func encode(_ value: Int8) throws { self.plaintext = value.description }
    func encode(_ value: Int16) throws { self.plaintext = value.description }
    func encode(_ value: Int32) throws { self.plaintext = value.description }
    func encode(_ value: Int64) throws { self.plaintext = value.description }
    func encode(_ value: UInt) throws { self.plaintext = value.description }
    func encode(_ value: UInt8) throws { self.plaintext = value.description }
    func encode(_ value: UInt16) throws { self.plaintext = value.description }
    func encode(_ value: UInt32) throws { self.plaintext = value.description }
    func encode(_ value: UInt64) throws { self.plaintext = value.description }
    func encode(_ value: Float) throws { self.plaintext = value.description }
    func encode<T>(_ value: T) throws where T: Encodable {
        if let data = value as? Data {
            // special case for data
            if let utf8 = data.withUnsafeBytes({ $0.withMemoryRebound(to: CChar.self, { String(validatingUTF8: $0.baseAddress!) }) }) {
                self.plaintext = utf8
            } else {
                self.plaintext = data.base64EncodedString()
            }
        } else {
            try value.encode(to: self)
        }
    }

    /// This ridiculosity is a workaround for the inability of encoders to throw errors in various places. It's still better than fatalError()ing.
    struct FailingEncoder: Encoder, UnkeyedEncodingContainer, SingleValueEncodingContainer {
        var codingPath: [CodingKey] { [] }
        var userInfo: [CodingUserInfoKey : Any] { [:] }
        var count: Int { 0 }
        private static var error: EncodingError { .invalidValue((), .init(codingPath: [], debugDescription: "Plaintext encoding does not support nesting.")) }

        struct FailingKeyedContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
            var codingPath: [CodingKey] { [] }
            func encodeNil(forKey: K) throws { throw FailingEncoder.error }
            func encode<T: Encodable>(_: T, forKey: K) throws { throw FailingEncoder.error }
            func nestedContainer<N: CodingKey>(keyedBy: N.Type, forKey: K) -> KeyedEncodingContainer<N> { .init(FailingKeyedContainer<N>()) }
            func nestedUnkeyedContainer(forKey: K) -> UnkeyedEncodingContainer { FailingEncoder() }
            func superEncoder() -> Encoder { FailingEncoder() }
            func superEncoder(forKey: K) -> Encoder { FailingEncoder() }
        }
        func container<K: CodingKey>(keyedBy: K.Type) -> KeyedEncodingContainer<K> { .init(FailingKeyedContainer<K>()) }
        func unkeyedContainer() -> UnkeyedEncodingContainer { self }
        func singleValueContainer() -> SingleValueEncodingContainer { self }
        func encodeNil() throws { throw FailingEncoder.error }
        func encode<T: Encodable>(_: T) throws { throw FailingEncoder.error }
        func nestedContainer<N: CodingKey>(keyedBy: N.Type) -> KeyedEncodingContainer<N> { .init(FailingKeyedContainer<N>()) }
        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { self }
        func superEncoder() -> Encoder { self }
    }
}
