import Foundation
import NIOCore
import HTTPTypes

/// Encodes data as plaintext, utf8.
public struct PlaintextEncoder: ContentEncoder {
    /// The specific plaintext `HTTPMediaType` to use.
    private let contentType: HTTPMediaType
    
    /// Creates a new `PlaintextEncoder`.
    ///
    /// - parameters:
    ///     - contentType: Plaintext `HTTPMediaType` to use. Usually `.plainText` or `.html`.
    public init(_ contentType: HTTPMediaType = .plainText) {
        self.contentType = contentType
    }
    
    // See `ContentEncoder.encode(_:to:headers:)`.
    public func encode(_ encodable: some Encodable, to body: inout ByteBuffer, headers: inout HTTPFields) throws {
        try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])
    }

    // See `ContentEncoder.encode(_:to:headers:userInfo:)`.
    public func encode(_ encodable: some Encodable, to body: inout ByteBuffer, headers: inout HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws {
        let encoder = _PlaintextEncoder(userInfo: userInfo)
        var container = encoder.singleValueContainer()
        try container.encode(encodable)

        guard let string = encoder.plaintext else {
            throw EncodingError.invalidValue(encodable, .init(codingPath: [], debugDescription: "Nothing was encoded!"))
        }
        headers.contentType = self.contentType
        body.writeString(string)
    }
}

// MARK: Private

private final class _PlaintextEncoder: Encoder, SingleValueEncodingContainer {
    let codingPath: [any CodingKey] = []
    let userInfoSendable: [CodingUserInfoKey: any Sendable]
    var userInfo: [CodingUserInfoKey: Any] { self.userInfoSendable }
    private(set) var plaintext: String?

    init(userInfo: [CodingUserInfoKey: any Sendable] = [:]) {
        self.userInfoSendable = userInfo
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> { .init(FailureEncoder<Key>()) }
    func unkeyedContainer() -> any UnkeyedEncodingContainer { FailureEncoder() }
    func singleValueContainer() -> any SingleValueEncodingContainer { self }

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
    
    func encode(_ value: some Encodable) throws {
        if let data = value as? Data {
            // special case for data
            if let utf8 = String(validating: data, as: UTF8.self) {
                self.plaintext = utf8
            } else {
                self.plaintext = data.base64EncodedString()
            }
        } else {
            try value.encode(to: self)
        }
    }

    /// This ridiculously is a workaround for the inability of encoders to throw errors in various places. It's still better than fatalError()ing.
    struct FailureEncoder<K: CodingKey>: Encoder, KeyedEncodingContainerProtocol, UnkeyedEncodingContainer, SingleValueEncodingContainer {
        let codingPath: [any CodingKey] = []
        let userInfo: [CodingUserInfoKey: Any] = [:]
        let count = 0

        var error: EncodingError {
            .invalidValue((), .init(codingPath: [], debugDescription: "Plaintext encoding does not support nesting."))
        }

        init() {}
        init() where K == BasicCodingKey {}

        func encodeNil() throws { throw self.error }
        func encodeNil(forKey: K) throws { throw self.error }

        func encode(_: some Encodable) throws { throw self.error }
        func encode(_: some Encodable, forKey: K) throws { throw self.error }

        func nestedContainer<N: CodingKey>(keyedBy: N.Type) -> KeyedEncodingContainer<N> { .init(FailureEncoder<N>()) }
        func nestedContainer<N: CodingKey>(keyedBy: N.Type, forKey: K) -> KeyedEncodingContainer<N> { .init(FailureEncoder<N>()) }

        func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer { self }
        func nestedUnkeyedContainer(forKey: K) -> any UnkeyedEncodingContainer { self }

        func superEncoder() -> any Encoder { self }
        func superEncoder(forKey: K) -> any Encoder { self }

        func container<Key: CodingKey>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> { .init(FailureEncoder<Key>()) }
        func unkeyedContainer() -> any UnkeyedEncodingContainer { self }
        func singleValueContainer() -> any SingleValueEncodingContainer { self }
    }
}
