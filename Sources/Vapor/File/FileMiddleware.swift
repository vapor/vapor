import Foundation
import HTTP
import libc

/// Servers files from the supplied public directory
/// on not found errors.
public final class FileMiddleware: Middleware {

    private var publicDir: String
    private let loader = DataFile()
    private let chunkSize: Int

    public init(publicDir: String, chunkSize: Int? = nil) {
        // Remove last "/" from the publicDir if present, so we can directly append uri path from the request.
        self.publicDir = publicDir.finished(with: "/")
        self.chunkSize = chunkSize ?? 32_768 // 2^15
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        do {
            return try next.respond(to: request)
        } catch let error as AbortError where error.status == .notFound {
            // Check in file system
            var path = request.uri.path
            guard !path.contains("../") else { throw HTTP.Status.forbidden }
            if path.hasPrefix("/") {
                path = String(path.characters.dropFirst())
            }
            let filePath = publicDir + path

            guard
                let attributes = try? Foundation.FileManager.default.attributesOfItem(atPath: filePath),
                let modifiedAt = attributes[.modificationDate] as? Date,
                let fileSize = attributes[.size] as? NSNumber
            else {
                throw Abort.notFound
            }

            var headers: [HeaderKey: String] = [:]

            // Generate ETag value, "HEX value of last modified date" + "-" + "file size"
            let fileETag = "\(modifiedAt.timeIntervalSince1970)-\(fileSize.intValue)"
            headers["ETag"] = fileETag

            // Check if file has been cached already and return NotModified response if the etags match
            if fileETag == request.headers["If-None-Match"] {
                return Response(status: .notModified, headers: headers, body: .data([]))
            }

            // Set Content-Type header based on the media type
            // Only set Content-Type if file not modified and returned above.
            if
                let fileExtension = filePath.components(separatedBy: ".").last,
                let type = Request.mediaTypes[fileExtension]
            {
                headers["Content-Type"] = type
            }

            // Try to open the file for reading, keeping it open until the chunking finishes.
            // This is the last chance to report a Not Found error to the client.
            guard let file = fopen(filePath, "r") else {
                throw Abort.notFound
            }

            // make copy of size for closure
            let chunkSize = self.chunkSize

            // return chunked response
            return Response(status: .ok, headers: headers, chunked: { stream in
                // the deferred fclose call must stay inside the chunking closure,
                // so the file does not get prematurely closed.
                defer {
                    fclose(file)
                }

                var buffer = Array(repeating: 0, count: chunkSize)
                var bytesRead: size_t = 0

                repeat {
                    bytesRead = fread(&buffer, 1, chunkSize, file)
                    if bytesRead > 0 {
                        // copy the buffer into an array
                        let chunk = Array(UnsafeRawBufferPointer(
                            start: buffer,
                            count: bytesRead
                        ))

                        // write the chunk to the chunk stream
                        try stream.write(chunk)
                    }
                } while bytesRead == chunkSize

                try stream.close()
            })
        }
    }
}
