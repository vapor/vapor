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
        get { return self.headers.firstValue(name: .contentType) }
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
            return self.contentDisposition?.parameters["filename"]
        }
        set {
            var disposition: HTTPHeaderValue
            if let existing = self.contentDisposition {
                disposition = existing
            } else {
                disposition = HTTPHeaderValue("form-data")
            }
            disposition.parameters["filename"] = newValue
            self.contentDisposition = disposition
        }
    }
    
    public var contentDisposition: HTTPHeaderValue? {
        get { self.headers.firstValue(name: .contentDisposition).flatMap { .parse($0) } }
        set {
            if let value = newValue {
                self.headers.replaceOrAdd(name: .contentDisposition, value: value.serialize())
            } else {
                self.headers.remove(name: .contentDisposition)
            }
        }
    }
}
