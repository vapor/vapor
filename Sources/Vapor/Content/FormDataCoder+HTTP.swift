import Random

extension FormDataDecoder: HTTPMessageDecoder {
    /// See `HTTPMessageDecoder`.
    public func decode<D, M>(_ decodable: D.Type, from message: M, maxSize: Int, on worker: Worker) throws -> Future<D>
        where D: Decodable, M: HTTPMessage
    {
        guard message.contentType == .formData else {
            throw VaporError(identifier: "contentType", reason: "HTTP message did not have multipart/form-data content-type.", source: .capture())
        }
        guard let boundary = message.contentType?.parameters["boundary"] else {
            throw VaporError(identifier: "contentType", reason: "HTTP message did not have multipart/form-data boundary.", source: .capture())
        }
        return message.body.consumeData(max: maxSize, on: worker).map(to: D.self) { data in
            return try self.decode(D.self, from: data, boundary: boundary)
        }
    }
}

extension FormDataEncoder: HTTPMessageEncoder {
    /// See `HTTPMessageEncoder`.
    public func encode<E, M>(_ encodable: E, to message: inout M, on worker: Worker) throws
        where E: Encodable, M: HTTPMessage
    {
        let random = OSRandom().generateData(count: 16)
        let boundary: String = "---vaporBoundary\(random.hexEncodedString())"
        message.contentType = MediaType(type: "multipart", subType: "form-data", parameters: ["boundary": boundary])
        message.body = try HTTPBody(data: encode(encodable, boundary: boundary))
    }
}
