extension URLEncodedFormDecoder: HTTPMessageDecoder {
    /// See `HTTPMessageDecoder`
    public func decode<D, M>(_ decodable: D.Type, from message: M, maxSize: Int, on worker: Worker) throws -> Future<D>
        where D: Decodable, M: HTTPMessage
    {
        guard message.contentType == .urlEncodedForm else {
            throw VaporError(identifier: "contentType", reason: "HTTP message did not have form-urlencoded content-type.", source: .capture())
        }
        return message.body.consumeData(max: maxSize, on: worker).map(to: D.self) { data in
            return try self.decode(D.self, from: data)
        }
    }
}

extension URLEncodedFormEncoder: HTTPMessageEncoder {
    /// See `HTTPMessageEncoder`
    public func encode<E, M>(_ encodable: E, to message: inout M, on worker: Worker) throws
        where E: Encodable, M: HTTPMessage
    {
        message.contentType = .urlEncodedForm
        message.body = try HTTPBody(data: encode(encodable))
    }
}
