import MultipartKit
import HTTPTypes
import NIOCore

extension FormDataDecoder: ContentDecoder {
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPFields) throws -> D
        where D: Decodable
    {
        try self.decode(D.self, from: body, headers: headers, userInfo: [:])
    }
    
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws -> D
        where D: Decodable
    {
        guard let boundary = headers.contentType?.parameters["boundary"] else {
            throw Abort(.unsupportedMediaType)
        }

        var body = body
        let buffer = body.readBytes(length: body.readableBytes) ?? []

        guard Array("--\(boundary)\r\n--\(boundary)--\r".utf8) != buffer else {
            throw Abort(.unprocessableContent, identifier: "emptyMultipartFormData")
        }

        if !userInfo.isEmpty {
            var actualDecoder = self // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            actualDecoder.userInfo.merge(userInfo) { $1 }
            return try actualDecoder.decode(D.self, from: buffer, boundary: boundary)
        } else {
            return try self.decode(D.self, from: buffer, boundary: boundary)
        }
    }
}
