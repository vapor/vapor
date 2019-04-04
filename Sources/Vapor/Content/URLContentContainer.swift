extension HTTPRequest {
    public var query: URLContentContainer {
        get { return .init(url: self.url) }
        set { self.url = newValue.url }
    }
}

/// Helper for encoding and decoding data from an HTTP request query string.
///
/// See `Request.query` for more information.
public struct URLContentContainer {
    /// URL query string or ""
    internal var url: URL
    
    internal init(url: URL) {
        self.url = url
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
    public mutating func encode<E>(_ encodable: E) throws where E: Encodable {
        try requireEncoder().encode(encodable, to: &self.url)
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
        return try requireDecoder().decode(D.self, from: self.url)
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
    public subscript<D>(_ keyPath: HTTPCodingKeyRepresentable...) -> D?
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
    public subscript<D>(_ type: D.Type, at keyPath: HTTPCodingKeyRepresentable...) -> D?
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
    public subscript<D>(_ type: D.Type, at keyPath: [HTTPCodingKeyRepresentable]) -> D?
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
    public func get<D>(_ type: D.Type = D.self, at keyPath: HTTPCodingKeyRepresentable...) throws -> D
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
    public func get<D>(_ type: D.Type = D.self, at keyPath: [HTTPCodingKeyRepresentable]) throws -> D
        where D: Decodable
    {
        return try requireDecoder().get(at: keyPath.map { $0.makeHTTPCodingKey() }, from: self.url)
    }

    // MARK: Private

    /// Gets the`DataDecoder` or throws an error.
    private func requireDecoder() throws -> URLContentDecoder {
        return try ContentConfiguration.global.requireURLDecoder()
    }

    /// Gets the `DataEncoder` or throws an error.
    private func requireEncoder() throws -> URLContentEncoder {
        return try ContentConfiguration.global.requireURLEncoder()
    }
}
