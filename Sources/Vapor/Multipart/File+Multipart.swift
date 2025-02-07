import MultipartKit
import NIOHTTP1

extension File: MultipartPartConvertible {
    public var multipart: MultipartPart? {
        var part = MultipartPart(headers: [:], body: .init(self.data.readableBytesView))
        part.contentType = self.extension
            .flatMap { HTTPMediaType.fileExtension($0) }
            .flatMap { $0.serialize() }
        part.filename = self.filename
        return part
    }

    public init?(multipart: MultipartPart) {
        guard let filename = multipart.filename else {
            return nil
        }
        self.init(data: multipart.body, filename: filename)
    }
}

extension MultipartPart {
    public var contentType: String? {
        get {
            self.headers.first(name: .contentType)
        }
        set {
            if let value = newValue {
                self.headers.replaceOrAdd(name: .contentType, value: value)
            } else {
                self.headers.remove(name: .contentType)
            }
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

    public var contentDisposition: HTTPHeaders.ContentDisposition? {
        get {
            self.headers.contentDisposition
        }
        set {
            self.headers.contentDisposition = newValue
        }
    }
}
