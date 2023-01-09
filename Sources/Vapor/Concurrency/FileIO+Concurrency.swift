#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension FileIO {
    /// Reads the contents of a file at the supplied path.
    ///
    ///     let data = try await req.fileio().read(file: "/path/to/file.txt")
    ///     print(data) // file data
    ///
    /// - parameters:
    ///     - path: Path to file on the disk.
    /// - returns: `ByteBuffer` containing the file data.
    public func collectFile(at path: String) async throws -> ByteBuffer {
        return try await self.collectFile(at: path).get()
    }
    
    /// Reads the contents of a file at the supplied path in chunks.
    ///
    ///     try await req.fileio().readChunked(file: "/path/to/file.txt") { chunk in
    ///         print("chunk: \(data)")
    ///     }
    ///
    /// - parameters:
    ///     - path: Path to file on the disk.
    ///     - chunkSize: Maximum size for the file data chunks.
    ///     - onRead: Closure to be called sequentially for each file data chunk.
    /// - returns: `Void` when the file read is finished.
    // public func readFile(at path: String, chunkSize: Int = NonBlockingFileIO.defaultChunkSize, onRead: @escaping (ByteBuffer) async throws -> Void) async throws {
    //     // TODO
    //     // We should probably convert the internal private read function to async as well rather than wrapping it at this top level
    //     let promise = self.request.eventLoop.makePromise(of: Void.self)
    //     promise.completeWithTask {
    //         try await onRead
    //     }
    //     let closureFuture = promise.futureResult
    //     return try self.readFile(at: path, onRead: closureFuture).get()
    // }
    
    /// Write the contents of buffer to a file at the supplied path.
    ///
    ///     let data = ByteBuffer(string: "ByteBuffer")
    ///     try await req.fileio.writeFile(data, at: "/path/to/file.txt")
    ///
    /// - parameters:
    ///     - path: Path to file on the disk.
    ///     - buffer: The `ByteBuffer` to write.
    /// - returns: `Void` when the file write is finished.
    public func writeFile(_ buffer: ByteBuffer, at path: String) async throws {
        return try await self.writeFile(buffer, at: path).get()
    }
}
#endif
