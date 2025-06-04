import MultipartKit
import HTTPTypes
import NIOCore

extension FormDataEncoder: ContentEncoder {
    public func encode(_ encodable: some Encodable, to body: inout ByteBuffer, headers: inout HTTPFields) throws {
        try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])
    }

    public func encode(_ encodable: some Encodable, to body: inout ByteBuffer, headers: inout HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws {
        let boundary = "----vaporBoundary\(randomBoundaryData())"

        headers.contentType = HTTPMediaType.formData(boundary: boundary)
        if !userInfo.isEmpty {
            var actualEncoder = self  // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy

            actualEncoder.userInfo.merge(userInfo) { $1 }
            let view = try actualEncoder.encode(encodable, boundary: boundary, to: ByteBufferView.self)
            body.writeBytes(view)
        } else {
            let view = try self.encode(encodable, boundary: boundary, to: ByteBufferView.self)
            body.writeBytes(view)
        }
    }
}

// MARK: Private

private let chars = "abcdefghijklmnopqrstuvwxyz0123456789"

private func randomBoundaryData() -> String {
    var string = ""
    for _ in 0..<16 {
        string.append(chars.randomElement()!)
    }
    return string
}
