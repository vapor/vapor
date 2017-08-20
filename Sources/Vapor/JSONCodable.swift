import HTTP
import Foundation

// MARK: Encodable

/// Can be encoded as JSON data.
public protocol JSONEncodable: Encodable {
    /// Encodes JSON representation to supplied Data.
    func encodeJSON(to data: inout Data) throws
}

extension JSONEncodable {
    /// See JSONEncodable.encode
    public func encodeJSON(to data: inout Data) throws {
        data = try JSONEncoder().encode(self)
    }
}

// MARK: Decodable

/// Can be decoded from JSON data.
public protocol JSONDecodable: Decodable {
    /// Decodes self from JSON representation.
    static func decodeJSON(from data: Data) throws -> Self
}

extension JSONDecodable {
    /// See JSONDecodable.decode
    public static func decodeJSON(from data: Data) throws -> Self {
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

// MARK: Codable

/// Can be encoded to and decoded from JSON data.
public typealias JSONCodable = JSONEncodable & JSONDecodable

// MARK: HTTP

/// Free implementation of ContentDecodable if you conform JSONCodable.

extension JSONDecodable where Self: ContentDecodable {
    /// See ContentDecodable.decode
    public static func decodeContent(from message: Message) throws -> Self? {
        guard message.mediaType == .json else {
            return nil
        }

        return try decodeJSON(from: message.body.data)
    }
}

extension JSONEncodable where Self: ContentEncodable {
    /// See ContentEncodable.encode
    public func encodeContent(to message: Message) throws {
        message.mediaType = .json
        return try encodeJSON(to: &message.body.data)
    }
}
