extension JSONEncoder: ContentEncoder {
    /// See `HTTPMessageEncoder`
    public func encode<E, M>(_ encodable: E, to message: inout M) throws
        where E: Encodable, M: HTTPMessage
    {
        message.contentType = .json
        message.body = try HTTPBody(data: encode(encodable))
    }
}

extension JSONDecoder: ContentDecoder {
    /// See `HTTPMessageDecoder`
    public func decode<D, M>(_ decodable: D.Type, from message: M) throws -> D
        where D: Decodable, M: HTTPMessage
    {
        guard message.contentType == .json || message.contentType == .jsonAPI else {
            throw HTTPError(.unknownContentType)
        }
        guard let data = message.body.data else {
            throw HTTPError(.noContent)
        }
        return try self.decode(D.self, from: data)
    }
}
