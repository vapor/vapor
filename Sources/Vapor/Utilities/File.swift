/// Represents a single file.
public struct File: Codable {
    /// Name of the file, including extension.
    public var filename: String
    
    /// The file's data.
    public var data: ByteBuffer
    
    /// Associated `MediaType` for this file's extension, if it has one.
    public var contentType: HTTPMediaType? {
        return ext.flatMap { HTTPMediaType.fileExtension($0.lowercased()) }
    }
    
    /// The file extension, if it has one.
    public var ext: String? {
        return filename.split(separator: ".").last.map(String.init)
    }
    
    public init(from decoder: Decoder) throws {
        fatalError()
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError()
    }
    
    /// Creates a new `File`.
    ///
    ///     let file = File(data: "hello", filename: "foo.txt")
    ///
    /// - parameters:
    ///     - data: The file's contents.
    ///     - filename: The name of the file, not including path.
    public init(data: String, filename: String) {
        var buffer = ByteBufferAllocator().buffer(capacity: data.utf8.count)
        buffer.writeString(data)
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
