extension JSONEncoder: ResponseEncoder {
    /// See `ResponseEncoder`
    public func encode<E>(_ encodable: E, to response: Response) throws
        where E: Encodable
    {
        response.headers.contentType = .json
        response.body = try .init(data: encode(encodable))
    }
}

extension JSONDecoder: RequestDecoder {
    /// See `RequestDecoder`
    public func decode<D>(_ decodable: D.Type, from request: Request) throws -> D
        where D: Decodable
    {
        guard request.headers.contentType == .json || request.headers.contentType == .jsonAPI else {
            throw HTTPStatus.unsupportedMediaType
        }
        guard let buffer = request.body.data else {
            throw HTTPStatus.notAcceptable
        }
        let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) ?? Data()
        return try self.decode(D.self, from: data)
    }
}
