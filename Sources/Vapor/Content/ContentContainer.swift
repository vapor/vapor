import NIOHTTP1
import NIOCore

public protocol ContentContainer {
    /// The type of data stored in the container.
    ///
    /// This is usually set according to the received data for incoming content.
    /// For outgoing content, the type is typically specified as part of encoding.
    var contentType: HTTPMediaType? { get }

    /// The configuration for encoding and decoding content.
    var contentConfiguration: ContentConfiguration { get }

    /// Use the provided ``ContentDecoder`` to read a value of type `D` from the container.
    func decode<D: Decodable>(_: D.Type, using decoder: ContentDecoder) throws -> D

    /// Use the provided ``ContentEncoder`` to write a value of type `E` to the container.
    mutating func encode<E: Encodable>(_ encodable: E, using encoder: ContentEncoder) throws
}

extension ContentContainer {
    // MARK: - Decoding helpers

    /// Use the default decoder for the container's ``contentType`` to read a value of type `D`
    /// from the container.
    public func decode<D: Decodable>(_: D.Type) throws -> D {
        return try self.decode(D.self, using: self.configuredDecoder())
    }

    /// Use the default decoder for the container's ``contentType`` to read a value of type `C`
    /// from the container.
    ///
    /// - Note: The ``Content/defaultContentType-9sljl`` of `C` is ignored.
    public func decode<C: Content>(_: C.Type) throws -> C {
        var content = try self.decode(C.self, using: self.configuredDecoder())
        try content.afterDecode()
        return content
    }

    /// Use the default configured decoder for the ``contentType`` parameter to read a value
    /// of type `D` from the container.
    public func decode<D: Decodable>(_: D.Type, as contentType: HTTPMediaType) throws -> D {
        try self.decode(D.self, using: self.configuredDecoder(for: contentType))
    }

    // MARK: - Encoding helpers

    /// Serialize a ``Content`` object to the container as its default content type.
    public mutating func encode<C: Content>(_ content: C) throws {
        try self.encode(content, as: C.defaultContentType)
    }

    /// Serialize a ``Content`` object to the container as its default content type without copying it.
    public mutating func encode<C: Content>(_ content: inout C) throws {
        try self.encode(&content, as: C.defaultContentType)
    }

    /// Serialize a ``Content`` object to the container, specifying an explicit content type.
    public mutating func encode<C: Content>(_ content: C, as contentType: HTTPMediaType) throws {
        var content = content
        try self.encode(&content, as: contentType)
    }
    
    /// Serialize a ``Content`` object to the container without copying it, specifying an
    /// explicit content type.
    public mutating func encode<C: Content>(_ content: inout C, as contentType: HTTPMediaType) throws {
        try content.beforeEncode()
        try self.encode(content, using: self.configuredEncoder(for: contentType))
    }

    /// Serialize an ``Encodable`` value to the container as the given ``HTTPMediaType``.
    public mutating func encode<E: Encodable>(_ encodable: E, as contentType: HTTPMediaType) throws {
        try self.encode(encodable, using: self.configuredEncoder(for: contentType))
    }

    // MARK: - Key path helpers
    
    /// Legacy alias for ``subscript(_:at:)-90mrm``.
    public subscript<D: Decodable>(_ path: CodingKeyRepresentable...) -> D? {
        self[D.self, at: path]
    }

    /// Fetch a single ``Decodable`` value at the supplied keypath in the container.
    ///
    ///     let name: String? = req.content[at: "user", "name"]
    public subscript<D: Decodable>(_: D.Type = D.self, at path: CodingKeyRepresentable...) -> D? {
        self[D.self, at: path]
    }

    /// Fetch a single ``Decodable`` value at the supplied keypath in the container.
    ///
    ///     let name: String? = req.content[at: ["user", "name"]]
    public subscript<D: Decodable>(_: D.Type = D.self, at path: [CodingKeyRepresentable]) -> D? {
        try? self.get(D.self, at: path)
    }
    
    /// Fetch a single ``Decodable`` value at the supplied keypath in the container.
    ///
    ///     let name: String = try req.content.get(at: "user", "name")
    public func get<D: Decodable>(_: D.Type = D.self, at path: CodingKeyRepresentable...) throws -> D {
        try self.get(at: path)
    }
    
    /// Fetch a single ``Decodable`` value at the supplied keypath in this container.
    ///
    ///     let name = try req.content.get(String.self, at: ["user", "name"])
    public func get<D: Decodable>(_: D.Type = D.self, at path: [CodingKeyRepresentable]) throws -> D {
        try self.get(D.self, path: path.map(\.codingKey))
    }
    
    // MARK: - Private
    
    /// Execute a "get at coding key path" operation.
    private func get<D: Decodable>(_: D.Type = D.self, path: [CodingKey]) throws -> D {
        try self.decode(ContainerGetPathExecutor<D>.self, using: ForwardingContentDecoder(
            base: self.configuredDecoder(),
            info: ContainerGetPathExecutor<D>.userInfo(for: path)
        )).result
    }

    /// Look up a ``ContentEncoder`` for the supplied ``HTTPMediaType``.
    private func configuredEncoder(for mediaType: HTTPMediaType) throws -> ContentEncoder {
        try self.contentConfiguration.requireEncoder(for: mediaType)
    }
    
    /// Look up a ``ContentDecoder`` for the container's ``contentType``.
    private func configuredDecoder(for mediaType: HTTPMediaType? = nil) throws -> ContentDecoder {
        guard let contentType = mediaType ?? self.contentType else {
            throw Abort(.unsupportedMediaType, reason: "Can't decode data without a content type")
        }
        return try self.contentConfiguration.requireDecoder(for: contentType)
    }
}

/// Injects coder userInfo into a ``ContentDecoder`` so we don't have to add passthroughs to ``ContentContainer``.
fileprivate struct ForwardingContentDecoder: ContentDecoder {
    let base: ContentDecoder, info: [CodingUserInfoKey: Sendable]
    
    func decode<D: Decodable>(_: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D {
        try self.base.decode(D.self, from: body, headers: headers, userInfo: self.info)
    }
    func decode<D: Decodable>(_: D.Type, from body: ByteBuffer, headers: HTTPHeaders, userInfo: [CodingUserInfoKey: Sendable]) throws -> D {
        try self.base.decode(D.self, from: body, headers: headers, userInfo: userInfo.merging(self.info) { $1 })
    }
}
