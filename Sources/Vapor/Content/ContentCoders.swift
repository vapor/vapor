import Foundation
import NIOCore
import HTTPTypes

/// Conform a type to this protocol to make it usable for encoding data via Vapor's ``ContentConfiguration`` system.
public protocol ContentEncoder: Sendable {
    /// Legacy "encode object" method. The provided encodable object's contents must be stored in the provided
    /// ``NIOCore/ByteBuffer``, and any appropriate headers for the type of the content may be stored in the provided
    /// ``HTTPTypes/HTTPFields``.
    ///
    /// Most encoders should implement this method by simply forwarding it to the encoder userInfo-aware version below,
    /// e.g. `try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])`. For legacy API compatibility
    /// reasons, the default protocol conformance will do the exact opposite.
    func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPFields) throws
        where E: Encodable

    /// "Encode object" method. The provided encodable object's contents must be stored in the provided
    /// ``NIOCore/ByteBuffer``, and any appropriate headers for the type of the content may be stored in the provided
    /// ``HTTPTypes/HTTPFields`` objects. The provided ``userInfo`` dictionary must be forwarded to the underlying
    /// ``Swift/Encoder`` used to perform the encoding operation.
    ///
    /// For legacy API compatibility reasons, the default protocol conformance for this method forwards it to the legacy
    /// encode method.
    func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws
        where E: Encodable
}

/// Conform a type to this protocol to make it usable for decoding data via Vapor's ``ContentConfiguration`` system.
public protocol ContentDecoder: Sendable {
    /// Legacy "decode object" method. The provided ``NIOCore/ByteBuffer`` should be decoded as a value of the given
    /// type, optionally guided by the provided ``HTTPTypes/HTTPFields``.
    ///
    /// Most decoders should implement this method by simply forwarding it to the decoder userInfo-aware version below,
    /// e.g. `try self.decode(D.self, from: body, headers: headers, userInfo: [:])`. For legacy API compatibility
    /// reasons, the default protocol conformance will do the exact opposite.
    func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPFields) throws -> D
        where D: Decodable

    /// "Decode object" method. The provided ``NIOCore/ByteBuffer`` should be decoded as a value of the given type,
    /// optionally guided by the provided ``HTTPTypes/HTTPFields``. The provided ``userInfo`` dictionary must be
    /// forwarded to the underlying ``Swift/Decoder`` used to perform the decoding operation.
    ///
    /// For legacy API compatibility reasons, the default protocol conformance for this method forwards it to the legacy
    /// decode method.
    func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws -> D
        where D: Decodable
}

extension ContentEncoder {
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws
        where E: Encodable
    {
        try self.encode(encodable, to: &body, headers: &headers)
    }
}

extension ContentDecoder {
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws -> D
        where D: Decodable
    {
        try self.decode(decodable, from: body, headers: headers)
    }
}
