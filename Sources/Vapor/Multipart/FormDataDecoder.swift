extension FormDataDecoder: ContentDecoder {
    /// `ContentDecoder` conformance.
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
        where D: Decodable
    {
        guard let boundary = headers.contentType?.parameters["boundary"] else {
            throw Abort(.unsupportedMediaType)
        }
        var body = body
        let buffer = body.readBytes(length: body.readableBytes) ?? []
        return try self.decode(D.self, from: buffer, boundary: boundary)
    }
}
