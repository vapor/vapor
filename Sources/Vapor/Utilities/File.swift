/// Represents a single file.
public struct File: Codable, Equatable {
    /// Name of the file, including extension.
    public var filename: String
    
    /// The file's data.
    public var data: ByteBuffer
    
    /// Associated `MediaType` for this file's extension, if it has one.
    public var contentType: HTTPMediaType? {
        return self.extension.flatMap { HTTPMediaType.fileExtension($0.lowercased()) }
    }
    
    /// The file extension, if it has one.
    public var `extension`: String? {
        let parts = self.filename.split(separator: ".")
        if parts.count > 1 {
            return parts.last.map(String.init)
        } else {
            return nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case data, filename
    }
    
    /// `Decodable` conformance.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .data)
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeBytes(data)
        let filename = try container.decode(String.self, forKey: .filename)
        self.init(data: buffer, filename: filename)
    }
    
    /// `Encodable` conformance.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let data = self.data.getData(at: self.data.readerIndex, length: self.data.readableBytes)
        try container.encode(data, forKey: .data)
        try container.encode(self.filename, forKey: .filename)
    }
    
    /// Creates a new `File`.
    ///
    ///     let file = File(data: "hello", filename: "foo.txt")
    ///
    /// - parameters:
    ///     - data: The file's contents.
    ///     - filename: The name of the file, not including path.
    public init(data: String, filename: String) {
        let buffer = ByteBufferAllocator().buffer(string: data)
        self.init(data: buffer, filename: filename)
    }
    
    /// Creates a new `File`.
    ///
    ///     let file = File(data: "hello", filename: "foo.txt")
    ///
    /// - parameters:
    ///     - data: The file's contents.
    ///     - filename: The name of the file, not including path.
    public init(data: ByteBuffer, filename: String) {
        self.data = data
        self.filename = filename
    }
}
