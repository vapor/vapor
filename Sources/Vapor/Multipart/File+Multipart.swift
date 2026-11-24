#if Multipart
public import MultipartKit
public import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension File: MultipartPartConvertible {
    public var headerFields: HTTPFields {
        var fields: HTTPFields = [:]
        fields.contentDisposition = .init(.formData, filename: filename)
        if let contentType = self.contentType?.serialize() {
            fields[.contentType] = contentType
        }
        return fields
    }

    public func withBody<R>(_ closure: (RawSpan) throws -> R) rethrows -> R {
        try closure(self.data.bytes)
    }

    public init(headerFields: HTTPFields, body: RawSpan) throws {
        guard
            let filename = headerFields.contentDisposition?.filename,
            !filename.isEmpty
        else {
            throw Abort(.badRequest, reason: "Missing filename")
        }

        let data = body.withUnsafeBytes { unsafe Data($0) }

        self.init(data: data, filename: filename, contentType: headerFields.contentType)
    }
}

extension MultipartPart {
    public var contentType: String? {
        get {
            self.headerFields[.contentType]
        }
        set {
            self.headerFields[.contentType] = newValue
        }
    }

    public var filename: String? {
        get {
            self.contentDisposition?.filename
        }
        set {
            if var existing = self.contentDisposition {
                existing.filename = newValue
                self.contentDisposition = existing
            } else {
                self.contentDisposition = .init(.formData, filename: newValue)
            }
        }
    }

    public var contentDisposition: HTTPFields.ContentDisposition? {
        get {
            self.headerFields.contentDisposition
        }
        set {
            self.headerFields.contentDisposition = newValue
        }
    }
}
#endif
