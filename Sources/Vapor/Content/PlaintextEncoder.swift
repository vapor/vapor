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
    ///     - contentType: Plaintext `MediaType` to use. Usually `.plainText` or `.html`.
    public init(_ contentType: HTTPMediaType = .plainText) {
        self.encoder = .init()
        self.contentType = contentType
    }
    
    /// `ContentEncoder` conformance.
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
    {
        try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])
    }
    
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders, userInfo: [CodingUserInfoKey: Sendable]) throws
        where E: Encodable
    {
        let actualEncoder: _PlaintextEncoder
        if !userInfo.isEmpty {  // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            actualEncoder = _PlaintextEncoder(userInfo: self.encoder.userInfo.merging(userInfo) { $1 })
        } else {
            actualEncoder = self.encoder
        }

        var container = actualEncoder.singleValueContainer()
        try container.encode(encodable)

        guard let string = actualEncoder.plaintext else {
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
    
    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> { .init(FailureEncoder<Key>()) }
    public func unkeyedContainer() -> UnkeyedEncodingContainer { FailureEncoder() }
    public func singleValueContainer() -> SingleValueEncodingContainer { self }

    func encodeNil() throws { self.plaintext = nil }
    
    // N.B.: Implementing the individual "primitive" coding methods on a container rather than forwarding through
    // each type's Codable implementation yields substantial speedups.
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
#if swift(>=5.7.2)
            let utf8Maybe = data.withUnsafeBytes({ $0.withMemoryRebound(to: CChar.self, { String(validatingUTF8: $0.baseAddress!) }) })
#else
            let utf8Maybe = data.withUnsafeBytes({ String(validatingUTF8: $0.bindMemory(to: CChar.self).baseAddress!) })
#endif
            if let utf8 = utf8Maybe {
                self.plaintext = utf8
            } else {
                self.plaintext = data.base64EncodedString()
            }
        } else {
            try value.encode(to: self)
        }
    }

    /// This ridiculosity is a workaround for the inability of encoders to throw errors in various places. It's still better than fatalError()ing.
    struct FailureEncoder<K: CodingKey>: Encoder, KeyedEncodingContainerProtocol, UnkeyedEncodingContainer, SingleValueEncodingContainer {
        let codingPath = [CodingKey](), userInfo = [CodingUserInfoKey: Any](), count = 0
        var error: EncodingError { .invalidValue((), .init(codingPath: [], debugDescription: "Plaintext encoding does not support nesting.")) }
        init() {}; init() where K == BasicCodingKey {}
        func encodeNil() throws { throw self.error }
        func encodeNil(forKey: K) throws { throw self.error }
        func encode<T: Encodable>(_: T) throws { throw self.error }
        func encode<T: Encodable>(_: T, forKey: K) throws { throw self.error }
        func nestedContainer<N: CodingKey>(keyedBy: N.Type) -> KeyedEncodingContainer<N> { .init(FailureEncoder<N>()) }
        func nestedContainer<N: CodingKey>(keyedBy: N.Type, forKey: K) -> KeyedEncodingContainer<N> { .init(FailureEncoder<N>()) }
        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { self }
        func nestedUnkeyedContainer(forKey: K) -> UnkeyedEncodingContainer { self }
        func superEncoder() -> Encoder { self }
        func superEncoder(forKey: K) -> Encoder { self }
        func container<Key: CodingKey>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> { .init(FailureEncoder<Key>()) }
        func unkeyedContainer() -> UnkeyedEncodingContainer { self }
        func singleValueContainer() -> SingleValueEncodingContainer { self }
    }
}
