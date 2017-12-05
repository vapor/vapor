import HTTP
import Foundation

/// Encodes encodable types to an HTTP body.
public protocol BodyEncoder {
    /// Serializes an encodable type to the data in an HTTP body.
    func encodeBody<T: Encodable>(from encodable: T) throws -> HTTPBody
}

/// Decodes decodable types from an HTTP body.
public protocol BodyDecoder {
    /// Parses a decodable type from the data in the HTTP body.
    func decode<T: Decodable>(_ decodable: T.Type, from body: HTTPBody) throws -> T
}

// MARK: Foundation

extension JSONEncoder: BodyEncoder {
    public func encodeBody<T>(from encodable: T) throws -> HTTPBody where T : Encodable {
        let data = try self.encode(encodable)
        return HTTPBody(data)
    }
}

extension JSONDecoder: BodyDecoder {
    public func decode<T>(_ decodable: T.Type, from body: HTTPBody) throws -> T where T : Decodable {
        guard let data = body.data else {
            throw VaporError(identifier: "body-error", reason: "JSONDecodes doesn't support streaming bodies")
        }
        
        return try self.decode(T.self, from: data)
    }
}
