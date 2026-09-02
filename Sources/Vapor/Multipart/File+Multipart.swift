#if Multipart
public import MultipartKit
public import HTTPTypes
#warning("Remove")
import NIOCore
import NIOFoundationEssentialsCompat
#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

extension File: MultipartPartConvertible {
    public typealias Body = Data

    public var multipart: MultipartPart<Data> {
        var part = MultipartPart(headerFields: [:], body: self.data.getData(at: 0, length: self.data.readableBytes) ?? Data())
        part.contentType = self.contentType?.serialize()
        part.filename = self.filename
        return part
    }
    
    public init(multipart: MultipartPart<some MultipartPartBodyElement>) throws {
        guard let filename = multipart.filename else {
            throw Abort(.badRequest, reason: "Missing filename")
        }
        let contentType = multipart.headerFields.contentType
        self.init(data: ByteBuffer(bytes: multipart.body), filename: filename, contentType: contentType)
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
