/// A single part of a `multipart`-encoded message.
public struct MultipartPart: Equatable {
    /// The part's headers.
    public var headers: HTTPHeaders

    /// The part's raw data.
    public var body: ByteBuffer
    
    /// Gets or sets the `name` attribute from the part's `"Content-Disposition"` header.
    public var name: String? {
        get { self.headers.getParameter("Content-Disposition", "name") }
        set { self.headers.setParameter("Content-Disposition", "name", to: newValue, defaultValue: "form-data") }
    }

    /// Creates a new `MultipartPart`.
    ///
    ///     let part = MultipartPart(headers: ["Content-Type": "text/plain"], body: "hello")
    ///
    /// - parameters:
    ///     - headers: The part's headers.
    ///     - body: The part's data.
    public init(headers: HTTPHeaders = .init(), body: String) {
        self.init(headers: headers, body: [UInt8](body.utf8))
    }

    /// Creates a new `MultipartPart`.
    ///
    ///     let part = MultipartPart(headers: ["Content-Type": "text/plain"], body: "hello")
    ///
    /// - parameters:
    ///     - headers: The part's headers.
    ///     - body: The part's data.
    public init<Data>(headers: HTTPHeaders = .init(), body: Data)
        where Data: DataProtocol
    {
        var buffer = ByteBufferAllocator().buffer(capacity: body.count)
        buffer.writeBytes(body)
        self.init(headers: headers, body: buffer)
    }
    
    public init(headers: HTTPHeaders = .init(), body: ByteBuffer) {
        self.headers = headers
        self.body = body
    }
}

// MARK: Array Extensions

extension Array where Element == MultipartPart {
    /// Returns the first `MultipartPart` with matching name attribute in `"Content-Disposition"` header.
    public func firstPart(named name: String) -> MultipartPart? {
        for el in self {
            if el.name == name {
                return el
            }
        }
        return nil
    }

    /// Returns all `MultipartPart`s with matching name attribute in `"Content-Disposition"` header.
    public func allParts(named name: String) -> [MultipartPart] {
        return filter { $0.name == name }
    }
}
