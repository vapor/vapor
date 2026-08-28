#if Multipart
public import MultipartKit
public import HTTPTypes
#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

extension FormDataEncoder: ContentEncoder {
    public func encode(_ encodable: some Encodable, to body: inout Data, headers: inout HTTPFields, userInfo: [CodingUserInfoKey : any Sendable]) throws {
        let boundary = "----vaporBoundary\(randomBoundaryData())"

        headers.contentType = HTTPMediaType.formData(boundary: boundary)
        if !userInfo.isEmpty {
            var actualEncoder = self  // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy

            actualEncoder.userInfo.merge(userInfo) { $1 }
            let view = try actualEncoder.encode(encodable, boundary: boundary, to: Data.self)
            body.append(view)
        } else {
            let view = try self.encode(encodable, boundary: boundary, to: Data.self)
            body.append(view)
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
#endif
