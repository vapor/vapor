import Foundation
import HTTP
import libc

/// Servers files from the supplied public directory
/// on not found errors.
public final class FileMiddleware: Middleware {

    private var publicDir: String
    private let loader = DataFile()

    public init(publicDir: String) {
        // Remove last "/" from the publicDir if present, so we can directly append uri path from the request.
        self.publicDir = publicDir.finished(with: "/")
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

            // Try to open the file for reading.
            // This is the last chance to report a Not Found error to the client.
            guard let file = fopen(filePath, "r") else {
                throw Abort.notFound
            }

            return Response(status: .ok, headers: headers, chunked: { stream in
                let chunkSize = 32768
 
                defer {
                    fclose(file)
                }

                guard let buffer = malloc(chunkSize) else {
                    try? stream.close()
                    return
                }

                defer {
                    free(buffer)
                }

                do {
                    var count: size_t = 0

                    repeat {
                        count = fread(buffer, 1, chunkSize, file)
                        if count > 0 {
                            let chunk = Array(UnsafeRawBufferPointer(start: buffer, count: count))
                            try stream.write(chunk)
                        }
                    } while count == chunkSize
                }
                catch {
                    // In chunked mode, the server has no way to indicate errors inside the body,
                    // so closing the stream after the first write error is effectively
                    // the only option to keep the server running.
                }

                try? stream.close()
            })
        }
    }
}
