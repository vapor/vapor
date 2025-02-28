import NIOCore

/// Helper for encoding and decoding data from an HTTP request query string.
///
/// See ``Request/query`` for more information.
public protocol URLQueryContainer {
    func decode<D: Decodable>(_ decodable: D.Type, using decoder: URLQueryDecoder) throws -> D

    mutating func encode<E: Encodable>(_ encodable: E, using encoder: URLQueryEncoder) throws

    var contentConfiguration: ContentConfiguration { get }
}

extension URLQueryContainer {
    // MARK: - Encoding helpers

    /// Serialize a ``Content`` object to the container.
    public mutating func encode<C: Content>(_ content: C) throws {
        var content = content
        try self.encode(&content)
    }
    
    /// Serialize a ``Content`` object to the container without copying it.
    public mutating func encode<C: Content>(_ content: inout C) throws {
        try content.beforeEncode()
        try self.encode(content, using: self.configuredEncoder())
    }

    /// Serialize an ``Encodable`` value to the container.
    public mutating func encode<E: Encodable>(_ encodable: E) throws {
        try self.encode(encodable, using: self.configuredEncoder())
    }
    
    // MARK: - Decoding helpers

    /// Parse a ``Content`` object from the container.
    public func decode<C: Content>(_ content: C.Type) throws -> C {
        var content = try self.decode(C.self, using: self.configuredDecoder())
        try content.afterDecode()
        return content
    }

    /// Parse a ``Decodable`` value from the container.
    public func decode<D: Decodable>(_: D.Type) throws -> D {
        try self.decode(D.self, using: self.configuredDecoder())
    }

    // MARK: - Key path helpers

    /// Legacy alias for ``subscript(_:at:)-26w0c``.
    public subscript<D: Decodable>(_ path: CodingKeyRepresentable...) -> D? {
        self[D.self, at: path]
    }

    /// Fetch a single ``Decodable`` value at the supplied keypath in the container.
    ///
    ///     let name: String? = req.query[at: "user", "name"]
    public subscript<D: Decodable>(_: D.Type = D.self, at path: CodingKeyRepresentable...) -> D? {
        self[D.self, at: path]
    }

    /// Fetch a single ``Decodable`` value at the supplied keypath in the container.
    ///
    ///     let name: String? = req.query[at: ["user", "name"]]
    public subscript<D: Decodable>(_: D.Type = D.self, at path: [CodingKeyRepresentable]) -> D? {
        try? self.get(D.self, at: path)
    }
    
    /// Fetch a single ``Decodable`` value at the supplied keypath in the container.
    ///
    ///     let name: String = try req.query.get(at: "user", "name")
    public func get<D: Decodable>(_: D.Type = D.self, at path: CodingKeyRepresentable...) throws -> D {
        try self.get(at: path)
    }
    
    /// Fetch a single ``Decodable`` value at the supplied keypath in this container.
    ///
    ///     let name = try req.query.get(String.self, at: ["user", "name"])
    public func get<D: Decodable>(_: D.Type = D.self, at path: [CodingKeyRepresentable]) throws -> D {
        try self.get(D.self, path: path.map(\.codingKey))
    }

    // MARK: Private

    /// Execute a "get at coding key path" operation.
    private func get<D: Decodable>(_: D.Type = D.self, path: [CodingKey]) throws -> D {
        try self.decode(ContainerGetPathExecutor<D>.self, using: ForwardingURLQueryDecoder(
            base: self.configuredDecoder(),
            info: ContainerGetPathExecutor<D>.userInfo(for: path)
        )).result
    }

    /// Look up a ``URLQueryDecoder``.
    private func configuredDecoder() throws -> URLQueryDecoder { try self.contentConfiguration.requireURLDecoder() }

    /// Look up a ``URLQueryEncoder``.
    private func configuredEncoder() throws -> URLQueryEncoder { try self.contentConfiguration.requireURLEncoder() }
}

/// Injects coder userInfo into a ``URLQueryDecoder`` so we don't have to add passthroughs to ``URLQueryContainer``.
fileprivate struct ForwardingURLQueryDecoder: URLQueryDecoder {
    let base: URLQueryDecoder, info: [CodingUserInfoKey: Sendable]
    
    func decode<D: Decodable>(_: D.Type, from url: URI) throws -> D { try self.base.decode(D.self, from: url, userInfo: self.info) }
    func decode<D: Decodable>(_: D.Type, from url: URI, userInfo: [CodingUserInfoKey: Sendable]) throws -> D {
        try self.base.decode(D.self, from: url, userInfo: userInfo.merging(self.info) { $1 })
    }
}
