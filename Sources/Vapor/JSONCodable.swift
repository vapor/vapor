import HTTP
import Foundation

// MARK: Encodable

/// Can be encoded as JSON data.
public protocol JSONEncodable: Encodable {
    /// Encodes JSON representation to supplied Data.
    func encodeJSON() throws -> Data
}

extension JSONEncodable {
    /// See JSONEncodable.encode
    public func encodeJSON() throws -> Data {
        return try JSONEncoder().encode(self)
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
        message.body.data = try encodeJSON()
    }
}

// MARK: Request & Response

extension Request {
    /// Create a new HTTP request using a JSONEncodable.
    public convenience init(
        method: HTTP.Method = .get,
        uri: URI = URI(),
        version: Version = Version(major: 1, minor: 1),
        headers: Headers = Headers(),
        json: JSONEncodable
        ) throws {
        try self.init(method: method, uri: uri, version: version, headers: headers, body: Body(json.encodeJSON()))
    }
}

extension Response {
    /// Create a new HTTP response using a JSONEncodable.
    public convenience init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        json: JSONEncodable
        ) throws {
        try self.init(version: version, status: status, headers: headers, body: Body(json.encodeJSON()))
    }
}
