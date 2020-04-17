public protocol ContentContainer {
    var contentType: HTTPMediaType? { get }

    func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D
        where D: Decodable

    mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws
        where E: Encodable
}

extension ContentContainer {
    // MARK: Decode

    public func decode<D>(_ content: D.Type) throws -> D where D: Decodable {
        return try self.decode(D.self, using: self.configuredDecoder())
    }

    public func decode<C>(_ decodable: C.Type) throws -> C where C: Content {
        var content = try self.decode(C.self, using: self.configuredDecoder())
        try content.afterDecode()

        return content
    }

    // MARK: Encode

    /// Serializes an `Encodable` object to this message using specific `HTTPMessageEncoder`.
    ///
    ///     try req.content.encode(user, using: JSONEncoder())
    ///
    /// - parameters:
    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
    /// - throws: Errors during serialization.
    public mutating func encode<C>(_ encodable: C) throws
        where C: Content
    {
        var encodable = encodable
        try encodable.beforeEncode()
        try self.encode(encodable, as: C.defaultContentType)
    }


    /// Serializes an `Encodable` object to this message using specific `HTTPMessageEncoder`.
    ///
    ///     try req.content.encode(user, using: JSONEncoder())
    ///
    /// - parameters:
    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
    ///     - encoder: Specific `HTTPMessageEncoder` to use.
    /// - throws: Errors during serialization.
    public mutating func encode<E>(_ encodable: E, as contentType: HTTPMediaType) throws
        where E: Encodable
    {
        try self.encode(encodable, using: self.configuredEncoder(for: contentType))
    }

    /// Serializes a `Content` object to this message using specific `HTTPMessageEncoder`.
    ///
    ///     try req.content.encode(user, using: JSONEncoder())
    ///
    /// - parameters:
    ///     - content: Instance of generic `Content` to serialize to this HTTP message.
    ///     - encoder: Specific `HTTPMessageEncoder` to use.
    /// - throws: Errors during serialization.
    public mutating func encode<C>(_ content: C, as contentType: HTTPMediaType) throws
        where C: Content
    {
        var content = content
        try content.beforeEncode()
        try self.encode(content, using: self.configuredEncoder(for: contentType))
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
    public subscript<D>(_ keyPath: CodingKeyRepresentable...) -> D?
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
    public subscript<D>(_ type: D.Type, at keyPath: CodingKeyRepresentable...) -> D?
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
    public subscript<D>(_ type: D.Type, at keyPath: [CodingKeyRepresentable]) -> D?
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
    public func get<D>(_ type: D.Type = D.self, at keyPath: CodingKeyRepresentable...) throws -> D
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
    public func get<D>(_ type: D.Type = D.self, at keyPath: [CodingKeyRepresentable]) throws -> D
        where D: Decodable
    {
        return try self.decode(SingleValueDecoder.self).get(at: keyPath.map { $0.codingKey })
    }
    
    // MARK: Private

    /// Looks up a `HTTPMessageEncoder` for the supplied `MediaType`.
    private func configuredEncoder(for mediaType: HTTPMediaType) throws -> ContentEncoder {
        return try ContentConfiguration.global.requireEncoder(for: mediaType)
    }
    
    /// Looks up a `HTTPMessageDecoder` for the supplied `MediaType`.
    private func configuredDecoder() throws -> ContentDecoder {
        guard let contentType = self.contentType else {
            throw Abort(.unsupportedMediaType)
        }
        return try ContentConfiguration.global.requireDecoder(for: contentType)
    }
}
