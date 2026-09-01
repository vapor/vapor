#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import _NIOFileSystem
import HTTPTypes
import Logging
import Crypto
import NIOConcurrencyHelpers
import _NIOFileSystemFoundationCompat
import NIOHTTP1

extension Request {
    public func fileio(etagCache: FileETagHashCache) -> FileIO {
        return .init(
            request: self,
            fileETagHashCache: etagCache,
        )
    }
}

// MARK: FileIO

/// `FileIO` is a convenience wrapper around SwiftNIO's `FileSystem`.
///
/// It can read files, both in their entirety and chunked.
///
///     try await req.fileio.readFile(at: "/path/to/file.txt") { chunks in
///         for try await chunk in chunks {
///             print(chunk) // part of file
///         }
///     }
///
///     let file = try await req.fileio.collectFile(at: "/path/to/file.txt")
///     print(file) // entire file
///
/// It can also create streaming HTTP responses.
///
///     app.get("file-stream") { req -> Response in
///         return try await req.fileio.streamFile(at: "/path/to/file.txt")
///     }
///
/// Streaming file responses respect `E-Tag` headers present in the request.
public struct FileIO: Sendable {
    /// Cache for eTag hashes for each file
    let fileETagHashCache: FileETagHashCache

    let request: Request

    let fileSystem: FileSystem = .shared

    /// Creates a new ``FileIO``.
    internal init(request: Request, fileETagHashCache: FileETagHashCache) {
        self.fileETagHashCache = fileETagHashCache
        self.request = request
    }

    /// Generates a fresh ETag for a file or returns its currently cached one.
    /// - Parameters:
    ///   - path: The file's path.
    ///   - lastModified: When the file was last modified.
    /// - Returns: A `String` which holds the ETag.
    private func generateETagHash(path: String, lastModified: Date, size: Int64) async throws -> String {
        try await self.fileETagHashCache.digestHex(
            forFileAt: path,
            lastModified: lastModified,
            size: size
        ) {
            try await FileSystem.shared.withFileHandle(forReadingAt: .init(path)) { handle in
                // Hashing in chunks is constant memory and has no size ceiling.
                var hasher = SHA256()
                for try await chunk in handle.readChunks(chunkLength: .bytes(128 * 1024)) {
                    hasher.update(data: chunk.readableBytesView)
                }
                return hasher.finalize().hex
            }
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
    ///         return try await req.fileio.streamFile(at: "/path/to/file.txt")
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
            Logger.current.debug("Range header was provided in request but was invalid")
            throw Abort(.badRequest)
        } else {
            contentRange = nil
        }

        let eTag: String

        if advancedETagComparison {
            eTag = try await generateETagHash(
                path: path,
                lastModified: fileInfo.lastDataModificationTime.date,
                size: Int64(fileInfo.size))
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
            return Response(status: .notModified, headersNoUpdate: headers, body: .empty)
        }

        // Create the HTTP response.
        let responseStatus: HTTPResponse.Status
        let offset: Int64
        let byteCount: Int
        if let contentRange = contentRange {
            responseStatus = .partialContent
            headers[.accept] = contentRange.unit.serialize()
            if let firstRange = contentRange.ranges.first {
                do {
                    let range = try firstRange.asResponseContentRange(limit: Int(fileInfo.size))
                    headers.contentRange = HTTPFields.ContentRange(unit: contentRange.unit, range: range)
                    (offset, byteCount) = try firstRange.asByteBufferBounds(withMaxSize: Int(fileInfo.size))
                } catch {
                    throw Abort(.badRequest)
                }
            } else {
                offset = 0
                byteCount = Int(fileInfo.size)
            }
        } else {
            responseStatus = .ok
            offset = 0
            byteCount = Int(fileInfo.size)
        }
        // Set Content-Type header based on the media type
        // Only set Content-Type if file not modified and returned above.
        if
            let fileExtension = path.components(separatedBy: ".").last,
            let type = mediaType ?? HTTPMediaType.fileExtension(fileExtension)
        {
            headers.contentType = type
        }

        let fileSystem = self.fileSystem
        var response = Response(status: responseStatus, headers: headers)
        response.body = try .init(stream: { writer in
            // The scoped `withFileHandle` API would close the handle for us, but its `execute`
            // parameter is `@concurrent` from here (Vapor builds with `NonisolatedNonsendingByDefault`,
            // NIO doesn't), so the closure would have to be sent — and it captures the non-Sendable
            // `writer`. So we open by hand, and write each chunk with `await` so the transport
            // backpressures the read.
            let handle: ReadFileHandle
            do {
                handle = try await fileSystem.openFile(forReadingAt: FilePath(path), options: .init())
            } catch {
                try await onCompleted(.failure(error))
                throw error
            }
            // Wrap the close handle in a task to avoid inheriting cancellation. We always want to close the
            // handle, but without it we can hit a subtle issue where the defer would be cancelled before
            // close had triggered, leading to a crash
            defer { await Task { try? await handle.close() }.value }

            do {
                let chunks = handle.readChunks(
                    in: offset..<(offset + Int64(byteCount)),
                    chunkLength: .bytes(chunkSize)
                )
                for try await chunk in chunks {
                    try await writer.write(chunk.readableBytesSpan)
                }
            } catch {
                try await onCompleted(.failure(error))
                throw error
            }
            try await onCompleted(.success(()))
        }, count: byteCount)

        return response
    }
}

extension HTTPFields.Range.Value {

    fileprivate func asByteBufferBounds(withMaxSize size: Int) throws -> (offset: Int64, byteCount: Int) {
        switch self {
            case .start(let value):
                guard value <= size, value >= 0 else {
                    Logger.current.debug("Requested range start was invalid: \(value)")
                    throw Abort(.badRequest)
                }
                return (offset: numericCast(value), byteCount: size - value)
            case .tail(let value):
                guard value <= size, value >= 0 else {
                    Logger.current.debug("Requested range end was invalid: \(value)")
                    throw Abort(.badRequest)
                }
                return (offset: numericCast(size - value), byteCount: value)
            case .within(let start, let end):
                guard start >= 0, end >= 0, start <= end, start <= size, end <= size else {
                    Logger.current.debug("Requested range was invalid: \(start)-\(end)")
                    throw Abort(.badRequest)
                }
                let (byteCount, overflow) =  (end - start).addingReportingOverflow(1)
                guard !overflow else {
                    Logger.current.debug("Requested range was invalid: \(start)-\(end)")
                    throw Abort(.badRequest)
                }
                return (offset: numericCast(start), byteCount: byteCount)
        }
    }
}
