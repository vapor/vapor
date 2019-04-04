/// Serializes `MultipartForm`s to `Data`.
///
/// See `MultipartParser` for more information about the multipart encoding.
public final class MultipartSerializer {
    /// Creates a new `MultipartSerializer`.
    public init() { }
    
    public func serialize(parts: [MultipartPart], boundary: String) throws -> String {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        try self.serialize(parts: parts, boundary: boundary, into: &buffer)
        return buffer.readString(length: buffer.readableBytes)!
    }
    
    /// Serializes the `MultipartForm` to data.
    ///
    ///     let data = try MultipartSerializer().serialize(parts: [part], boundary: "123")
    ///     print(data) // multipart-encoded
    ///
    /// - parameters:
    ///     - parts: One or more `MultipartPart`s to serialize into `Data`.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    /// - throws: Any errors that may occur during serialization.
    /// - returns: `multipart`-encoded `Data`.
    public func serialize(parts: [MultipartPart], boundary: String, into buffer: inout ByteBuffer) throws {
        for part in parts {
            buffer.writeString("--")
            buffer.writeString(boundary)
            buffer.writeString("\r\n")
            for (key, val) in part.headers {
                buffer.writeString(key)
                buffer.writeString(": ")
                buffer.writeString(val)
                buffer.writeString("\r\n")
            }
            buffer.writeString("\r\n")
            var body = part.body
            buffer.writeBuffer(&body)
            buffer.writeString("\r\n")
        }
        buffer.writeString("--")
        buffer.writeString(boundary)
        buffer.writeString("--\r\n")
    }
}
