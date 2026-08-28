#if Multipart
#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif
public import MultipartKit
public import HTTPTypes
import NIOCore

extension FormDataDecoder: ContentDecoder {
    public func decode<D>(_ decodable: D.Type, from body: Data, headers: HTTPFields, userInfo: [CodingUserInfoKey : any Sendable]) throws -> D where D : Decodable {
        guard let boundary = headers.contentType?.parameters["boundary"] else {
            throw Abort(.unsupportedMediaType)
        }

        guard !body.elementsEqual("--\(boundary)\r\n--\(boundary)--\r".utf8) else {
            throw Abort(.unprocessableContent, identifier: "emptyMultipartFormData")
        }

        if !userInfo.isEmpty {
            var actualDecoder = self // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            actualDecoder.userInfo.merge(userInfo) { $1 }
            return try actualDecoder.decode(D.self, from: body, boundary: boundary)
        } else {
            return try self.decode(D.self, from: body, boundary: boundary)
        }
    }
}
#endif
