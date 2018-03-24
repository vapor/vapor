import Foundation

/// Helper for encoding and decoding data from an HTTP request query string.
///
/// See `Request.query` for more information.
public struct QueryContainer {
    /// Service container, used to access `ContentCoders`.
    internal var container: SubContainer

    /// HTTP request query string being decoded.
    internal var query: String
}

extension QueryContainer {
    /// Parses a `Decodable` type from this HTTP request query string.
    ///
    ///     let flags = try req.query.decode(Flags.self)
    ///     print(flags) /// Flags
    ///
    /// A `MediaType.urlEncodedForm` decoder will be used.
    ///
    /// - parameters:
    ///     - content: `Decodable` type to decode from this HTTP message.
    /// - returns: Instace of the `Decodable` type.
    /// - throws: Any errors making the decoder for this media type or parsing the query string.
    public func decode<D>(_ decodable: D.Type) throws -> D where D: Decodable {
        return try requireDataDecoder().decode(D.self, from: query)
    }

    /// Gets the`DataDecoder` or throws an error
    fileprivate func requireDataDecoder() throws -> DataDecoder {
        return try container.superContainer.make(ContentCoders.self).requireDataDecoder(for: .urlEncodedForm)
    }
}

// MARK: Single value

extension QueryContainer {
    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP request's query string.
    ///
    /// Note: This is a non-throwing subscript convenience method for `get(_:at:)`.
    ///
    ///     let name: String? = req.query["user", "name"]
    ///     print(name) /// String?
    ///
    /// - parameters:
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Decoded `Decodable` value.
    public subscript<D>(_ keyPath: BasicKeyRepresentable...) -> D?
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP request's query string.
    ///
    /// Note: This is a non-throwing subscript convenience method for `get(_:at:)`.
    ///
    ///     let name = req.query[String.self, at: "user", "name"]
    ///     print(name) /// String?
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Decoded `Decodable` value.
    public subscript<D>(_ type: D.Type, at keyPath: BasicKeyRepresentable...) -> D?
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP request's query string.
    ///
    /// Note: This is a non-throwing subscript convenience method for `get(_:at:)`. This is the non-variadic version.
    ///
    ///     let name = req.query[String.self, at: "user", "name"]
    ///     print(name) /// String?
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Decoded `Decodable` value.
    public subscript<D>(_ type: D.Type, at keyPath: [BasicKeyRepresentable]) -> D?
        where D: Decodable
    {
        return try? get(at: keyPath)
    }

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP request's query string.
    ///
    ///     let name = try req.query.get(String.self, at: "user", "name")
    ///     print(name) /// String
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Decoded `Decodable` value.
    public func get<D>(_ type: D.Type = D.self, at keyPath: BasicKeyRepresentable...) throws -> D
        where D: Decodable
    {
        return try get(at: keyPath)
    }

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP request's query string.
    ///
    /// Note: This is the non-variadic version.
    ///
    ///     let name = try req.query.get(String.self, at: "user", "name")
    ///     print(name) /// String
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Decoded `Decodable` value.
    public func get<D>(_ type: D.Type = D.self, at keyPath: [BasicKeyRepresentable]) throws -> D
        where D: Decodable
    {
        return try requireDataDecoder().get(at: keyPath.makeBasicKeys(), from: Data(query.utf8))
    }
}
