#if Multipart
import MultipartKit
import HTTPTypes
import NIOCore

extension File: MultipartPartConvertible {
    public typealias Body = ByteBufferView

    public var multipart: MultipartPart<ByteBufferView> {
        var part = MultipartPart(headerFields: [:], body: self.data.readableBytesView)
        part.contentType = self.contentType?.serialize()
        part.filename = self.filename
        return part
    }
    
    public init(multipart: MultipartPart<some MultipartPartBodyElement>) throws {
        guard let filename = multipart.filename else {
            throw Abort(.badRequest)
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
