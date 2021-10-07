#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension FileIO {
    public func collectFile(at path: String) async throws -> ByteBuffer {
        try self.collectFile(at: path).get()
    }
    
    public func readFile(at path: String, chunkSize: Int = NonBlockingFileIO.defaultChunkSize, onRead: @escaping (ByteBuffer) async throws -> Void
    ) async throws {
        // TODO
        // We should probably convert the internal private read function to async as well rather than wrapping it at this top level
        let promise = self.request.eventLoop.makePromise(of: Void.self)
        promise.completeWithTask {
            try await onRead
        }
        let closureFuture = promise.futureResult
        return try self.readFile(at: path, onRead: closureFuture).get()
    }
    
    public func writeFile(_ buffer: ByteBuffer, at path: String) async throws {
        try self.writeFile(buffer, at: path).get()
    }
}
#endif
