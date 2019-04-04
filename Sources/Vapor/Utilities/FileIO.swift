#warning("TODO: re-add methods with controller-based FileIO")
//extension HTTPRequestContext {
//    /// Creates a `FileIO` for this `Request`.
//    ///
//    ///     let data = try req.fileio().read(file: "/path/to/file.txt")
//    ///     print(data) // Future<Data>
//    ///
//    /// See `FileIO` for more information.
//    public func fileio() throws -> FileIO {
//        let allocator: ByteBufferAllocator
//        if let channel = http.channel {
//            allocator = channel.allocator
//        } else {
//            debugOnly { WARNING("FileIO: No channel on HTTPRequest. Initializing a new ByteBufferAllocator.") }
//            allocator = .init()
//        }
//        return try .init(io: make(), allocator: allocator, on: self)
//    }
//
//    /// If you are simply looking to serve files from your public directory,
//    /// it may be useful to look at 'FileMiddleware' instead.
//    ///
//    /// Use this to initialize a file response for the exact file path.
//    /// If using from a public folder for example, the file name should be appended
//    /// to the public directory, ie: `drop.publicDir + "myFile.cool"`
//    ///
//    /// If none match represents an ETag that will be used to check if the file has
//    /// changed since the last load by the client. This allows clients like browsers
//    /// to cache their files and avoid downloading resources unnecessarily.
//    /// Most often calculated w/
//    /// https://tools.ietf.org/html/rfc7232#section-3.2
//    ///
//    /// For an example of how this is used, look at 'FileMiddleware'.
//    ///
//    /// See `FileIO` for more information.
//    public func streamFile(at path: String) throws -> EventLoopFuture<HTTPResponse> {
//        let res = try fileio().chunkedResponse(file: path, for: http)
//        return self.eventLoop.makeSucceededFuture(result: res)
//    }
//}

// MARK: FileIO

/// `FileIO` is a convenience wrapper around SwiftNIO's `NonBlockingFileIO`.
///
/// It can read files, both in their entirety and chunked.
///
///     let data = try req.fileio().read(file: "/path/to/file.txt").wait()
///     print(data) // file data
///
/// It can also create HTTP chunked streams for use as HTTP bodies.
///
///     router.get("file-stream") { req -> HTTPResponse in
///         let stream = try req.fileio().chunkedStream(file: "/path/to/file.txt")
///         var res = HTTPResponse(status: .ok, body: stream)
///         res.contentType = .plainText
///         return res
///     }
///
/// Use `Request.fileio()` to create one.
public struct FileIO {
    /// Wrapped non-blocking file io from SwiftNIO
    private let io: NonBlockingFileIO

    /// ByteBufferAllocator to use for generating buffers.
    private let allocator: ByteBufferAllocator

    /// Event loop for async work.
    public let eventLoop: EventLoop

    /// Creates a new `FileIO`.
    ///
    /// See `Request.fileio()` to create one.
    internal init(io: NonBlockingFileIO, allocator: ByteBufferAllocator, on eventLoop: EventLoop) {
        self.io = io
        self.allocator = allocator
        self.eventLoop = eventLoop
    }

    /// Reads the contents of a file at the supplied path.
    ///
    ///     let data = try req.fileio().read(file: "/path/to/file.txt").wait()
    ///     print(data) // file data
    ///
    /// - parameters:
    ///     - file: Path to file on the disk.
    /// - returns: `Future` containing the file data.
    public func read(file: String) -> EventLoopFuture<ByteBuffer> {
        var data = self.allocator.buffer(capacity: 0)
        return readChunked(file: file) { new in
            var new = new
            data.writeBuffer(&new)
        }.map { data }
    }

    /// Reads the contents of a file at the supplied path in chunks.
    ///
    ///     try req.fileio().readChunked(file: "/path/to/file.txt") { chunk in
    ///         print("chunk: \(data)")
    ///     }.wait()
    ///
    /// - parameters:
    ///     - file: Path to file on the disk.
    ///     - chunkSize: Maximum size for the file data chunks.
    ///     - onRead: Closure to be called sequentially for each file data chunk.
    /// - returns: `Future` that will complete when the file read is finished.
    public func readChunked(file: String, chunkSize: Int = NonBlockingFileIO.defaultChunkSize, onRead: @escaping (ByteBuffer) -> Void) -> EventLoopFuture<Void> {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: file),
            let fileSize = attributes[.size] as? NSNumber
        else {
            return self.eventLoop.makeFailedFuture(Abort(.internalServerError))
        }
        return self.read(path: file, fileSize: fileSize.intValue, chunkSize: chunkSize, onRead: onRead)
    }

    /// Generates a chunked `HTTPResponse` for the specified file. This method respects values in
    /// the `"ETag"` header and is capable of responding `304 Not Modified` if the file in question
    /// has not been modified since last served. This method will also set the `"Content-Type"` header
    /// automatically if an appropriate `MediaType` can be found for the file's suffix.
    ///
    ///     router.get("file-stream") { req -> HTTPResponse in
    ///         return try req.fileio().chunkedResponse(file: "/path/to/file.txt")
    ///     }
    ///
    /// - parameters:
    ///     - file: Path to file on the disk.
    ///     - req: `HTTPRequest` to parse `"If-None-Match"` header from.
    ///     - chunkSize: Maximum size for the file data chunks.
    /// - returns: A `200 OK` response containing the file stream and appropriate headers.
    public func streamFile(at path: String, for request: Request, chunkSize: Int = NonBlockingFileIO.defaultChunkSize) -> Response {
        // Get file attributes for this file.
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let modifiedAt = attributes[.modificationDate] as? Date,
            let fileSize = (attributes[.size] as? NSNumber)?.intValue
        else {
            return Response(status: .internalServerError)
        }

        // Create empty headers array.
        var headers: HTTPHeaders = [:]

        // Generate ETag value, "HEX value of last modified date" + "-" + "file size"
        let fileETag = "\(modifiedAt.timeIntervalSince1970)-\(fileSize)"
        headers.replaceOrAdd(name: .eTag, value: fileETag)

        // Check if file has been cached already and return NotModified response if the etags match
        if fileETag == request.headers.firstValue(name: .ifNoneMatch) {
            return Response(status: .notModified)
        }

        // Create the HTTP response.
        let response = Response(status: .ok, headers: headers)

        // Set Content-Type header based on the media type
        // Only set Content-Type if file not modified and returned above.
        if
            let fileExtension = path.components(separatedBy: ".").last,
            let type = HTTPMediaType.fileExtension(fileExtension)
        {
            response.headers.contentType = type
        }

        response.body = .init(stream: { stream in
            self.read(path: path, fileSize: fileSize, chunkSize: chunkSize) { chunk in
                stream.write(.buffer(chunk))
            }.whenComplete { result in
                switch result {
                case .failure(let error):
                    stream.write(.error(error))
                case .success:
                    stream.write(.end)
                }
            }
        }, count: fileSize)
        
        return response
    }

    /// Private read method. `onRead` closure uses ByteBuffer and expects future return.
    /// There may be use in publicizing this in the future for reads that must be async.
    private func read(path: String, fileSize: Int, chunkSize: Int, onRead: @escaping (ByteBuffer) -> ()) -> EventLoopFuture<Void> {
        do {
            let fd = try NIOFileHandle(path: path)
            let done = self.io.readChunked(fileHandle: fd, byteCount: fileSize, chunkSize: chunkSize, allocator: allocator, eventLoop: eventLoop) { chunk in
                onRead(chunk)
                return self.eventLoop.makeSucceededFuture(())
            }
            done.whenComplete { _ in
                try? fd.close()
            }
            return done
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
}
