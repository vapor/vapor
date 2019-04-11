extension JSONEncoder: ContentEncoder {
    /// `ContentEncoder` conformance.
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
    {
        headers.contentType = .json
        try body.writeBytes(self.encode(encodable))
    }
}

extension JSONDecoder: ContentDecoder {
    /// `ContentDecoder` conformance.
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
        where D: Decodable
    {
        guard headers.contentType == .json || headers.contentType == .jsonAPI else {
            throw Abort(.unsupportedMediaType)
        }
        let data = body.getData(at: body.readerIndex, length: body.readableBytes) ?? Data()
        return try self.decode(D.self, from: data)
    }
}
