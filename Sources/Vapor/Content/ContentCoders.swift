#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif
import NIOCore
public import HTTPTypes

/// Conform a type to this protocol to make it usable for encoding data via Vapor's ``ContentConfiguration`` system.
public protocol ContentEncoder: Sendable {
    /// "Encode object" method. The provided encodable object's contents must be stored in the provided
    /// ``Foundation/Data``, and any appropriate headers for the type of the content may be stored in the provided
    /// ``HTTPTypes/HTTPFields`` objects. The provided ``userInfo`` dictionary must be forwarded to the underlying
    /// ``Swift/Encoder`` used to perform the encoding operation.
    func encode(_ encodable: some Encodable, to body: inout Data, headers: inout HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws
}

/// Conform a type to this protocol to make it usable for decoding data via Vapor's ``ContentConfiguration`` system.
public protocol ContentDecoder: Sendable {
    /// "Decode object" method. The provided ``Foundation/Data`` should be decoded as a value of the given type,
    /// optionally guided by the provided ``HTTPTypes/HTTPFields``. The provided ``userInfo`` dictionary must be
    /// forwarded to the underlying ``Swift/Decoder`` used to perform the decoding operation.
    func decode<D>(_ decodable: D.Type, from body: Data, headers: HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws -> D
        where D: Decodable
}
