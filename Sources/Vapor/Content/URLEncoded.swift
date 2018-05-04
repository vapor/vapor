extension URLEncodedFormDecoder: HTTPMessageDecoder {
    /// See `HTTPMessageDecoder`.
    public func decode<D, M>(_ decodable: D.Type, from message: M, maxSize: Int, on worker: Worker) throws -> Future<D>
        where D: Decodable, M: HTTPMessage
    {
        guard message.contentType == .urlEncodedForm else {
            throw VaporError(
                identifier: "contentType",
                reason: "\(M.self)'s content type does not indicate a URL-encoded form: \(message.contentType?.description ?? "none")",
                possibleCauses: [
                    "\(M.self) does not contain a URL-Encoded form.",
                    "\(M.self) is missing the 'Content-Type' header.",
                ]
            )
        }
        return message.body.consumeData(max: maxSize, on: worker).map { data in
            return try self.decode(D.self, from: data)
        }
    }
}

extension URLEncodedFormEncoder: HTTPMessageEncoder {
    /// See `HTTPMessageEncoder`.
    public func encode<E, M>(_ encodable: E, to message: inout M, on worker: Worker) throws
        where E: Encodable, M: HTTPMessage
    {
        message.contentType = .urlEncodedForm
        message.body = try HTTPBody(data: encode(encodable))
    }
}
