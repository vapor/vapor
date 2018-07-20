/// Helper for encoding and decoding data from an HTTP request query string.
///
/// See `Request.query` for more information.
public struct QueryContainer {
    /// Wrapped `Request`
    internal var req: Request

    /// URL query string or ""
    internal var query: String {
        return req.http.url.query ?? ""
    }

    // MARK: Content

    /// Serializes an `Encodable` type to this HTTP request query string.
    ///
    ///     let flags: Flags ...
    ///     try req.query.encode(flags)
    ///
    /// A `MediaType.urlEncodedForm` encoder will be used.
    ///
    /// - parameters:
    ///     - encodable: `Encodable` type to encode to this HTTP message.
    /// - throws: Any errors making the decoder for this media type or serializing the query string.
    public func encode<E>(_ encodable: E) throws where E: Encodable {
        guard var comps = URLComponents.init(string: req.http.urlString) else {
            throw VaporError(identifier: "parseURL", reason: "Could not parse URL components.")
        }
        let data = try requireDataEncoder().encode(encodable)
        comps.percentEncodedQuery = String(data: data, encoding: .utf8)
        guard let url = comps.url else {
            throw VaporError(identifier: "serializeURL", reason: "Could not serialize URL components.")
        }
        req.http.url = url
    }

    /// Parses a `Decodable` type from this HTTP request query string.
    ///
    ///     let flags = try req.query.decode(Flags.self)
    ///     print(flags) // Flags
    ///
    /// A `MediaType.urlEncodedForm` decoder will be used.
    ///
    /// - parameters:
    ///     - decodable: `Decodable` type to decode from this HTTP message.
    /// - returns: Instance of the `Decodable` type.
    /// - throws: Any errors making the decoder for this media type or parsing the query string.
    public func decode<D>(_ decodable: D.Type) throws -> D where D: Decodable {
        return try requireDataDecoder().decode(D.self, from: query)
    }

    // MARK: Single Value

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

    // MARK: Private

    /// Gets the`DataDecoder` or throws an error.
    private func requireDataDecoder() throws -> DataDecoder {
        return try req.make(ContentCoders.self).requireDataDecoder(for: .urlEncodedForm)
    }

    /// Gets the `DataEncoder` or throws an error.
    private func requireDataEncoder() throws -> DataEncoder {
        return try req.make(ContentCoders.self).requireDataEncoder(for: .urlEncodedForm)
    }
}
