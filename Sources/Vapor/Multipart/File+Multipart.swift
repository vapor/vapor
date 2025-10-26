#if Multipart
import MultipartKit
import HTTPTypes
import NIOCore

extension File: MultipartPartConvertible {
    public var multipart: MultipartPart<ByteBufferView>? {
        var part = MultipartPart(headerFields: [:], body: self.data.readableBytesView)
        part.contentType = self.extension
            .flatMap { HTTPMediaType.fileExtension($0) }
            .flatMap { $0.serialize() }
        part.filename = self.filename
        return part
    }
    
    public init?(multipart: MultipartPart<some MultipartPartBodyElement>) {
        guard let filename = multipart.filename else {
            return nil
        }
        self.init(data: ByteBuffer(bytes: multipart.body), filename: filename)
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
