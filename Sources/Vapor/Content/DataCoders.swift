import Foundation

/// Encodes encodable types to an HTTP body.
public protocol DataEncoder {
    /// Serializes an encodable type to the data in an HTTP body.
    func encode<T: Encodable>(_ encodable: T) throws -> Data
}

/// Decodes decodable types from an HTTP body.
public protocol DataDecoder {
    /// Parses a decodable type from the data in the HTTP body.
    func decode<T: Decodable>(_ decodable: T.Type, from data: Data) throws -> T
}

// MARK: Foundation

extension JSONEncoder: DataEncoder {}
extension JSONDecoder: DataDecoder {}
