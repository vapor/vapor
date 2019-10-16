///// A single part of a `multipart`-encoded message.
//public struct MultipartPart: Equatable {
//    /// The part's headers.
//    public var headers: [String: String]
//    
//    /// The part's raw data.
//    public var body: ByteBuffer
//    
//    /// Gets or sets the `filename` attribute from the part's `"Content-Disposition"` header.
//    public var filename: String? {
//        get { return contentDisposition?.parameters["filename"] }
//        set {
//            var value: HTTPHeaderValue
//            if let existing = contentDisposition {
//                value = existing
//            } else {
//                value = HTTPHeaderValue("form-data")
//            }
//            value.parameters["filename"] = newValue
//            contentDisposition = value
//        }
//    }
//
//    /// Gets or sets the `name` attribute from the part's `"Content-Disposition"` header.
//    public var name: String? {
//        get { return contentDisposition?.parameters["name"] }
//        set {
//            var value: HTTPHeaderValue
//            if let existing = contentDisposition {
//                value = existing
//            } else {
//                value = HTTPHeaderValue("form-data")
//            }
//            value.parameters["name"] = newValue
//            contentDisposition = value
//        }
//    }
//
//    /// Gets or sets the part's `"Content-Disposition"` header.
//    public var contentDisposition: HTTPHeaderValue? {
//        get { return headers["Content-Disposition"].flatMap { HTTPHeaderValue.parse($0) } }
//        set { headers["Content-Disposition"] = newValue?.serialize() }
//    }
//
//    /// Gets or sets the part's `"Content-Type"` header.
//    public var contentType: HTTPMediaType? {
//        get { return headers["Content-Type"].flatMap { HTTPMediaType.parse($0) } }
//        set { headers["Content-Type"] = newValue?.serialize() }
//    }
//
//    /// Creates a new `MultipartPart`.
//    ///
//    ///     let part = MultipartPart(headers: ["Content-Type": "text/plain"], body: "hello")
//    ///
//    /// - parameters:
//    ///     - headers: The part's headers.
//    ///     - body: The part's data.
//    public init(headers: [String: String] = [:], body: String) {
//        var buffer = ByteBufferAllocator().buffer(capacity: body.utf8.count)
//        buffer.writeString(body)
//        self.init(headers: headers, body: buffer)
//    }
//    
//    /// Creates a new `MultipartPart`.
//    ///
//    ///     let part = MultipartPart(headers: ["Content-Type": "text/plain"], body: "hello")
//    ///
//    /// - parameters:
//    ///     - headers: The part's headers.
//    ///     - body: The part's data.
//    public init(headers: [String: String] = [:], body: ByteBuffer) {
//        self.headers = headers
//        self.body = body
//    }
//}
//
//// MARK: Array Extensions
//
//extension Array where Element == MultipartPart {
//    /// Returns the first `MultipartPart` with matching name attribute in `"Content-Disposition"` header.
//    public func firstPart(named name: String) -> MultipartPart? {
//        for el in self {
//            if el.name == name {
//                return el
//            }
//        }
//        return nil
//    }
//
//    /// Returns all `MultipartPart`s with matching name attribute in `"Content-Disposition"` header.
//    public func allParts(named name: String) -> [MultipartPart] {
//        return filter { $0.name == name }
//    }
//
//    /// Returns the first `MultipartPart` with matching filename attribute in `"Content-Disposition"` header.
//    public func firstFile(filename: String) -> MultipartPart? {
//        for el in self {
//            if el.filename == filename {
//                return el
//            }
//        }
//        return nil
//    }
//}
