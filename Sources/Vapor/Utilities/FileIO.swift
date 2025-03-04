import Foundation
import NIOCore
import _NIOFileSystem
import HTTPTypes
import Logging
import Crypto
import NIOConcurrencyHelpers
import _NIOFileSystemFoundationCompat

extension Request {
    public var fileio: FileIO {
        return .init(
            allocator: self.application.byteBufferAllocator,
            request: self
        )
    }
}

// MARK: FileIO

/// `FileIO` is a convenience wrapper around SwiftNIO's `FileSystem`.
///
/// It can read files, both in their entirety and chunked.
///
///
///     req.fileio.readFile(at: "/path/to/file.txt") { chunk in
///         print(chunk) // part of file
///     }
///
///     req.fileio.collectFile(at: "/path/to/file.txt").map { file in
///         print(file) // entire file
///     }
///
/// It can also create streaming HTTP responses.
///
///     app.get("file-stream") { req -> Response in
///         return req.fileio.streamFile(at: "/path/to/file.txt", for: req)
///     }
///
/// Streaming file responses respect `E-Tag` headers present in the request.
public struct FileIO: Sendable {
    /// ByteBufferAllocator to use for generating buffers.
    private let allocator: ByteBufferAllocator
    
    /// HTTP request context.
    let request: Request

    let fileSystem: FileSystem = .shared

    /// Creates a new `FileIO`.
    ///
    /// See `Request.fileio()` to create one.
    internal init(allocator: ByteBufferAllocator, request: Request) {
        self.allocator = allocator
        self.request = request
    }
    
    private func read(
        path: String,
        fromOffset offset: Int64,
        byteCount: Int
    ) async throws -> ByteBuffer {
        return try await FileSystem.shared.withFileHandle(forReadingAt: .init(path)) { handle in
            return try await handle.readChunk(fromAbsoluteOffset: offset, length: .bytes(Int64(byteCount)))
        }
    }

    /// Generates a fresh ETag for a file or returns its currently cached one.
    /// - Parameters:
    ///   - path: The file's path.
    ///   - lastModified: When the file was last modified.
    /// - Returns: A `String` which holds the ETag.
    private func generateETagHash(path: String, lastModified: Date) async throws -> String {
        if let hash = request.application.storage[FileMiddleware.ETagHashes.self]?[path], hash.lastModified == lastModified {
            return hash.digestHex
        } else {
            return try await FileSystem.shared.withFileHandle(forReadingAt: .init(path)) { handle in
                let buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(.max))
                let digest = SHA256.hash(data: buffer.readableBytesView)

                // update hash in dictionary
                request.application.storage[FileMiddleware.ETagHashes.self]?[path] = FileMiddleware.ETagHashes.FileHash(lastModified: lastModified, digestHex: digest.hex)

                return digest.hex
            }
        }
    }
    
    // MARK: - Concurrency
    /// Reads the contents of a file at the supplied path.
    ///
    ///     let data = try await req.fileio.collectFile(file: "/path/to/file.txt")
    ///     print(data) // file data
    ///
    /// - parameters:
    ///     - path: Path to file on the disk.
    /// - returns: `ByteBuffer` containing the file data.
    public func collectFile(at path: String) async throws -> ByteBuffer {
        guard let fileSize = try await FileSystem.shared.info(forFileAt: .init(path))?.size else {
            throw Abort(.internalServerError)
        }
        return try await self.read(path: path, fromOffset: 0, byteCount: Int(fileSize))
    }
    
    /// Wrapper around `NIOFileSystem.FileChunks`.
    /// This can be removed once `NIOFileSystem` reaches a stable API.
    public struct FileChunks: AsyncSequence {
        public typealias Element = ByteBuffer
        private let fileHandle: any _NIOFileSystem.FileHandleProtocol
        private let fileChunks: _NIOFileSystem.FileChunks

        init(fileChunks: _NIOFileSystem.FileChunks, fileHandle: some _NIOFileSystem.FileHandleProtocol) {
            self.fileChunks = fileChunks
            self.fileHandle = fileHandle
        }

        public struct FileChunksIterator: AsyncIteratorProtocol {
            private var iterator: _NIOFileSystem.FileChunks.AsyncIterator
            private let fileHandle: any _NIOFileSystem.FileHandleProtocol

            fileprivate init(wrapping iterator: _NIOFileSystem.FileChunks.AsyncIterator, fileHandle: some _NIOFileSystem.FileHandleProtocol) {
                self.iterator = iterator
                self.fileHandle = fileHandle
            }

            public mutating func next() async throws -> ByteBuffer? {
                let chunk = try await iterator.next()
                if chunk == nil {
                    // For convenience's sake, close when we hit EOF. Closing on error is left up to the caller.
                    try await fileHandle.close()
                }
                return chunk
            }
        }
        
        public func closeHandle() async throws {
            try await self.fileHandle.close()
        }

        public func makeAsyncIterator() -> FileChunksIterator {
            FileChunksIterator(wrapping: fileChunks.makeAsyncIterator(), fileHandle: fileHandle)
        }
    }

    /// Reads the contents of a file at the supplied path in chunks.
    ///
    ///    for try await chunk in try await req.fileio.readFile(at: "/path/to/file.txt") {
    ///        print("chunk: \(data)")
    ///    }
    ///
    /// > Warning: It's the caller's responsibility to close the file handle provided in ``FileChunks`` when finished.
    ///
    /// - parameters:
    ///     - path: Path to file on the disk.
    ///     - chunkSize: Maximum size for the file data chunks.
    ///     - offset: The offset to start reading from.
    ///     - byteCount: The number of bytes to read from the file. If `nil`, the file will be read to the end.
    /// - returns: `FileChunks` containing the file data chunks.
    public func readFile(
        at path: String,
        chunkSize: Int64 = 128 * 1024, // was the default in NonBlockingFileIO
        offset: Int64? = nil,
        byteCount: Int? = nil
    ) async throws -> FileChunks {
        let filePath = FilePath(path)
        
        let readHandle = try await fileSystem.openFile(forReadingAt: filePath)
        
        let chunks: _NIOFileSystem.FileChunks
        
        if let offset {
            if let byteCount {
                chunks = readHandle.readChunks(in: offset..<(offset+Int64(byteCount)), chunkLength: .bytes(chunkSize))
            } else {
                chunks = readHandle.readChunks(in: offset..., chunkLength: .bytes(chunkSize))
            }
        } else {
            chunks = readHandle.readChunks(chunkLength: .bytes(chunkSize))
        }

        return FileChunks(fileChunks: chunks, fileHandle: readHandle)
    }
    
    /// Write the contents of buffer to a file at the supplied path.
    ///
    ///     let data = ByteBuffer(string: "ByteBuffer")
    ///     try await req.fileio.writeFile(data, at: "/path/to/file.txt")
    ///
    /// > Warning: This method will overwrite the file if it already exists.
    ///
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to write.
    ///     - path: Path to file on the disk.
    public func writeFile(_ buffer: ByteBuffer, at path: String) async throws {
        // This returns the number of bytes written which we don't need
        _ = try await FileSystem.shared.withFileHandle(forWritingAt: .init(path), options: .newFile(replaceExisting: true)) { handle in
            try await handle.write(contentsOf: buffer, toAbsoluteOffset: 0)
        }
    }

    /// Generates a chunked `Response` for the specified file. This method respects values in
    /// the `"ETag"` header and is capable of responding `304 Not Modified` if the file in question
    /// has not been modified since last served. If `advancedETagComparison` is set to true,
    /// the response will have its ETag field set to a byte-by-byte hash of the requested file. If set to false, a simple ETag consisting of the last modified date and file size
    /// will be used. This method will also set the `"Content-Type"` header
    /// automatically if an appropriate `MediaType` can be found for the file's suffix.
    ///
    ///     app.get("file-stream") { req in
    ///         return req.fileio.streamFile(at: "/path/to/file.txt")
    ///     }
    ///
    /// - parameters:
    ///     - path: Path to file on the disk.
    ///     - chunkSize: Maximum size for the file data chunks.
    ///     - mediaType: HTTPMediaType, if not specified, will be created from file extension.
    ///     - advancedETagComparison: The method used when ETags are generated. If true, a byte-by-byte hash is created (and cached), otherwise a simple comparison based on the file's last modified date and size.
    ///     - onCompleted: Closure to be run on completion of stream.
    /// - returns: A `200 OK` response containing the file stream and appropriate headers.
    public func streamFile(
        at path: String,
        chunkSize: Int64 = 128 * 1024, // was the default in NonBlockingFileIO
        mediaType: HTTPMediaType? = nil,
        advancedETagComparison: Bool = false,
        onCompleted: @escaping @Sendable (Result<Void, any Error>) async throws -> () = { _ in }
    ) async throws -> Response {
        // Get file attributes for this file.
        guard let fileInfo = try await FileSystem.shared.info(forFileAt: .init(path)) else {
            throw Abort(.internalServerError)
        }

        let contentRange: HTTPFields.Range?
        if let rangeFromHeaders = request.headers.range {
            if rangeFromHeaders.unit == .bytes && rangeFromHeaders.ranges.count == 1 {
                contentRange = rangeFromHeaders
            } else {
                contentRange = nil
            }
        } else if request.headers[.range] != nil {
            // Range header was supplied but could not be parsed i.e. it was invalid
            request.logger.debug("Range header was provided in request but was invalid")
            throw Abort(.badRequest)
        } else {
            contentRange = nil
        }

        let eTag: String

        if advancedETagComparison {
            eTag = try await generateETagHash(path: path, lastModified: fileInfo.lastDataModificationTime.date)
        } else {
            // Generate ETag value, "last modified date in epoch time" + "-" + "file size"
            eTag = "\"\(fileInfo.lastDataModificationTime.seconds)-\(fileInfo.size)\""
        }
        
        // Create empty headers array.
        var headers: HTTPFields = [:]

        // Respond with lastModified header
        headers.lastModified = HTTPFields.LastModified(value: fileInfo.lastDataModificationTime.date)

        headers[.eTag] = eTag

        // Check if file has been cached already and return NotModified response if the etags match
        if eTag == request.headers[.ifNoneMatch] {
            // Per RFC 9110 here: https://www.rfc-editor.org/rfc/rfc9110.html#status.304
            // and here: https://www.rfc-editor.org/rfc/rfc9110.html#name-content-encoding
            // A 304 response MUST include the ETag header and a Content-Length header matching what the original resource's content length would have been were this a 200 response.
            headers[.contentLength] = fileInfo.size.description
            return Response(status: .notModified, version: .http1_1, headersNoUpdate: headers, body: .empty)
        }

        // Create the HTTP response.
        let response = Response(status: .ok, headers: headers)
        let offset: Int64
        let byteCount: Int
        if let contentRange = contentRange {
            response.status = .partialContent
            response.headers[.accept] = contentRange.unit.serialize()
            if let firstRange = contentRange.ranges.first {
                do {
                    let range = try firstRange.asResponseContentRange(limit: Int(fileInfo.size))
                    response.headers.contentRange = HTTPFields.ContentRange(unit: contentRange.unit, range: range)
                    (offset, byteCount) = try firstRange.asByteBufferBounds(withMaxSize: Int(fileInfo.size), logger: request.logger)
                } catch {
                    throw Abort(.badRequest)
                }
            } else {
                offset = 0
                byteCount = Int(fileInfo.size)
            }
        } else {
            offset = 0
            byteCount = Int(fileInfo.size)
        }
        // Set Content-Type header based on the media type
        // Only set Content-Type if file not modified and returned above.
        if
            let fileExtension = path.components(separatedBy: ".").last,
            let type = mediaType ?? HTTPMediaType.fileExtension(fileExtension)
        {
            response.headers.contentType = type
        }
        
        response.body = .init(asyncStream: { stream in
            do {
                let chunks = try await self.readFile(at: path, chunkSize: chunkSize, offset: offset, byteCount: byteCount)
                do {
                    for try await chunk in chunks {
                        try await stream.writeBuffer(chunk)
                    }
                    try? await chunks.closeHandle()
                } catch {
                    try? await chunks.closeHandle()
                    throw error
                }
                try await stream.write(.end)
                try await onCompleted(.success(()))
            } catch {
                try? await stream.write(.error(error))
                try await onCompleted(.failure(error))
            }
        }, count: byteCount, byteBufferAllocator: request.byteBufferAllocator)

        return response
    }
}

extension HTTPFields.Range.Value {
    
    fileprivate func asByteBufferBounds(withMaxSize size: Int, logger: Logger) throws -> (offset: Int64, byteCount: Int) {
        switch self {
            case .start(let value):
                guard value <= size, value >= 0 else {
                    logger.debug("Requested range start was invalid: \(value)")
                    throw Abort(.badRequest)
                }
                return (offset: numericCast(value), byteCount: size - value)
            case .tail(let value):
                guard value <= size, value >= 0 else {
                    logger.debug("Requested range end was invalid: \(value)")
                    throw Abort(.badRequest)
                }
                return (offset: numericCast(size - value), byteCount: value)
            case .within(let start, let end):
                guard start >= 0, end >= 0, start <= end, start <= size, end <= size else {
                    logger.debug("Requested range was invalid: \(start)-\(end)")
                    throw Abort(.badRequest)
                }
                let (byteCount, overflow) =  (end - start).addingReportingOverflow(1)
                guard !overflow else {
                    logger.debug("Requested range was invalid: \(start)-\(end)")
                    throw Abort(.badRequest)
                }
                return (offset: numericCast(start), byteCount: byteCount)
        }
    }
}
